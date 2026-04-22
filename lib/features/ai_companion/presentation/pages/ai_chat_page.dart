import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/ai_service.dart';
import '../../data/continuous_listening_service.dart';
import '../../data/memory_service.dart';
import '../../data/models/user_memory.dart';
import '../bloc/continuous_listen_bloc.dart';
import '../bloc/continuous_listen_event_state.dart';
import '../widgets/ai_theme_widgets.dart';
import '../widgets/continuous_listening_indicator.dart';
import '../widgets/memory_profile_sheet.dart';

// ── Chat message model ────────────────────────────────────────────────────

class _ChatMsg {
  final bool isAi;
  final String text;
  final List<String> imageUrls;
  final bool isListening; // live user-speech placeholder
  final bool isThinking;  // AI is generating (shows dots)
  final bool isLive;      // true = came from API, false = local fallback

  const _ChatMsg({
    required this.isAi,
    required this.text,
    this.imageUrls = const [],
    this.isListening = false,
    this.isThinking  = false,
    this.isLive      = false,
  });
}

// (AI responses now come from AiService — no local fakes needed)

// ─────────────────────────────────────────────────────────────────────────────
//  AiChatPage
// ─────────────────────────────────────────────────────────────────────────────

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  int _tab = 0;
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  late ContinuousListenBloc _listenBloc;

  // ── Memory + AI services ────────────────────────────────────────────────
  final MemoryService _memoryService = MemoryService();
  late  AiService     _aiService;
  bool _isAiThinking = false;

  final List<_ChatMsg> _messages = [
    const _ChatMsg(
      isAi: true,
      text: 'Hi! I\'m Gravity, your smart AI companion. 👋\nSay "Hey Gravity" or tap the mic to start continuous listening.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // AiService receives MemoryService so it can inject memory into prompts
    _aiService = AiService(memoryService: _memoryService);
    _listenBloc = ContinuousListenBloc(ContinuousListeningService());

    // Load persisted memory, then personalise the greeting
    _memoryService.load().then((mem) {
      if (!mem.isEmpty && mem.hasName && mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            isAi: true,
            text: 'Welcome back, ${mem.name}! 😊 Ready to help with ${mem.goals.isNotEmpty ? mem.goals.first : "anything"}.',
          ));
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _listenBloc.close();
    _aiService.clearContext();
    _memoryService.dispose();
    super.dispose();
  }

  // ── Message management ───────────────────────────────────────────────────

  void _addMsg(_ChatMsg msg) {
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _removeLastIfListening() {
    if (_messages.isNotEmpty && _messages.last.isListening) {
      setState(() => _messages.removeLast());
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Handle user speech transcript ─────────────────────────────────────────

  Future<void> _onUserTranscript(String transcript) async {
    _removeLastIfListening();

    // 1. Show user bubble immediately
    _addMsg(_ChatMsg(isAi: false, text: transcript));

    // 2. Show AI thinking indicator
    if (mounted) setState(() => _isAiThinking = true);
    _addMsg(const _ChatMsg(isAi: true, text: '', isThinking: true));

    // 3. Call AI service — learn from user input AND get response
    AiResponse response;
    UserMemory? learnedMemory;
    try {
      final result = await _aiService.sendMessageWithMemory(transcript);
      response      = result.response;
      learnedMemory = result.learnedMemory;
    } catch (e) {
      response = AiResponse(
        text: 'Oops — something went wrong. Try again? 🔄',
        isLive: false,
        error: e.toString(),
      );
    }

    if (!mounted) return;

    // 4. Remove thinking bubble, add real response
    setState(() {
      _isAiThinking = false;
      _messages.removeWhere((m) => m.isThinking);
    });

    final lower = transcript.toLowerCase();
    final hasImage = lower.contains('image') ||
        lower.contains('create') ||
        lower.contains('sunset') ||
        lower.contains('draw') ||
        lower.contains('picture') ||
        lower.contains('art');

    _addMsg(_ChatMsg(
      isAi: true,
      text: response.text,
      imageUrls: hasImage
          ? [
              'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=200&q=80',
              'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=200&q=80',
            ]
          : [],
      isLive: response.isLive,
    ));

    // 5. Show memory-learned toast if new info was extracted
    if (learnedMemory != null && mounted) {
      _showMemoryToast(learnedMemory);
    }

    // 6. Tell continuous-listen BLoC the AI finished → mic re-opens
    _listenBloc.notifyResponseComplete();
  }

  void _onStopCommand() {
    _removeLastIfListening();
    _aiService.clearContext(); // Fresh context on next session
    _addMsg(const _ChatMsg(
      isAi: true,
      text: '✋ Listening stopped. Tap the mic button to start again.',
    ));
  }

  // ── Manual text send ──────────────────────────────────────────────────────

  void _sendText() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _onUserTranscript(text);
  }

  // ── Memory toast ─────────────────────────────────────────────────────────

  void _showMemoryToast(UserMemory mem) {
    final parts = <String>[];
    if (mem.hasName)               parts.add('name: ${mem.name}');
    if (mem.goals.isNotEmpty)      parts.add('goal: ${mem.goals.last}');
    if (mem.studyTopics.isNotEmpty) parts.add('topic: ${mem.studyTopics.last}');

    final label = parts.isEmpty ? 'Learned something new!' : 'Remembered — ${parts.join(', ')}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: AiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AiColors.purple.withOpacity(0.5)),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AiColors.buttonGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    color: AiColors.textWhite, fontSize: 12.5),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: AiColors.purpleLight,
          onPressed: () => MemoryProfileSheet.show(context, _memoryService),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ContinuousListenBloc>.value(
      value: _listenBloc,
      child: BlocListener<ContinuousListenBloc, ContinuousListenState>(
        listener: (context, state) {
          if (state is ContinuousListenListening) {
            // Show a live "listening…" bubble
            _removeLastIfListening();
            _addMsg(const _ChatMsg(
              isAi: false,
              text: '',
              isListening: true,
            ));
          } else if (state is ContinuousListenProcessing) {
            _removeLastIfListening();
            _onUserTranscript(state.userTranscript);
          } else if (state is ContinuousListenStopped) {
            if (state.reason == 'command') _onStopCommand();
          }
        },
        child: Scaffold(
          backgroundColor: AiColors.background,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),

                // ── Top status indicator ───────────────────────
                const ContinuousListeningIndicator(),

                // ── Messages ───────────────────────────────────
                Expanded(child: _buildMessages()),

                // ── Continuous listening overlay (above input) ─
                const ContinuousListeningOverlay(),

                // ── Input bar ──────────────────────────────────
                _buildInputBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AiColors.surface,
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AiColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AiColors.textSub, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Title + memory indicator
          Expanded(
            child: StreamBuilder<UserMemory>(
              stream: _memoryService.memoryStream,
              initialData: _memoryService.current,
              builder: (_, snap) {
                final mem = snap.data ?? const UserMemory();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gravity',
                      style: TextStyle(
                        color: AiColors.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (mem.hasName)
                      Text(
                        'Hi, ${mem.name} 👋',
                        style: const TextStyle(
                          color: AiColors.textSub,
                          fontSize: 11,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Brain / Memory button
          GestureDetector(
            onTap: () => MemoryProfileSheet.show(context, _memoryService),
            child: StreamBuilder<UserMemory>(
              stream: _memoryService.memoryStream,
              initialData: _memoryService.current,
              builder: (_, snap) {
                final hasMemory = snap.data?.isEmpty == false;
                return Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: hasMemory ? AiColors.buttonGradient : null,
                        color: hasMemory ? null : AiColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasMemory
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: hasMemory
                            ? [BoxShadow(color: AiColors.purple.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: hasMemory ? Colors.white : AiColors.textSub,
                        size: 18,
                      ),
                    ),
                    if (hasMemory)
                      Positioned(
                        top: 0,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AiColors.orbCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Continuous listen toggle button in app bar
          BlocBuilder<ContinuousListenBloc, ContinuousListenState>(
            builder: (context, state) {
              final isActive = state is ContinuousListenListening ||
                  state is ContinuousListenProcessing;
              return GestureDetector(
                onTap: () =>
                    context.read<ContinuousListenBloc>().add(const ContinuousListenToggle()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: isActive ? AiColors.buttonGradient : null,
                    color: isActive ? null : AiColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AiColors.purple.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: isActive ? Colors.white : AiColors.textSub,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Messages list ───────────────────────────────────────────────────────

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        if (msg.isListening)  return _ListeningBubble(key: const ValueKey('listening'));
        if (msg.isThinking)   return const _AiThinkingBubble(key: ValueKey('thinking'));
        return _ChatBubble(msg: msg);
      },
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    return BlocBuilder<ContinuousListenBloc, ContinuousListenState>(
      builder: (ctx, state) {
        final isActive = state is ContinuousListenListening ||
            state is ContinuousListenProcessing;

        return Container(
          decoration: BoxDecoration(
            color: AiColors.surface,
            border:
                Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tab row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    _TabChip(
                        label: 'AI Assistant',
                        icon: Icons.smart_toy_outlined,
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: 8),
                    _TabChip(
                        label: 'Smart Chat',
                        icon: Icons.chat_bubble_outline,
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1)),
                    const SizedBox(width: 8),
                    _TabChip(
                        label: 'Virtual',
                        icon: Icons.person_outline,
                        selected: _tab == 2,
                        onTap: () => setState(() => _tab = 2)),
                  ],
                ),
              ),

              // Input row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    // Text field
                    Expanded(
                      child: Container(
                        height: 46,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AiColors.surfaceLight,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          onSubmitted: (_) => _sendText(),
                          style: const TextStyle(
                              color: AiColors.textWhite, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: isActive
                                ? 'Continuous mode active…'
                                : 'Ask me anything',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send / Mic button
                    GestureDetector(
                      onTap: () {
                        if (_inputCtrl.text.trim().isNotEmpty) {
                          _sendText();
                        } else {
                          context
                              .read<ContinuousListenBloc>()
                              .add(const ContinuousListenToggle());
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AiColors.buttonGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AiColors.purple.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _inputCtrl.text.isNotEmpty
                              ? Icons.send_rounded
                              : (isActive
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Listening placeholder bubble ──────────────────────────────────────────────

class _ListeningBubble extends StatefulWidget {
  const _ListeningBubble({super.key});

  @override
  State<_ListeningBubble> createState() => _ListeningBubbleState();
}

class _ListeningBubbleState extends State<_ListeningBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Live partial from BLoC
          BlocBuilder<ContinuousListenBloc, ContinuousListenState>(
            builder: (_, state) {
              final partial = state is ContinuousListenListening
                  ? state.partial
                  : '';
              return Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AiColors.purple, AiColors.purpleDark]),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AiColors.purple.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: partial.isNotEmpty
                      ? Text(
                          partial,
                          style: const TextStyle(
                            color: AiColors.textWhite,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _c,
                          builder: (_, __) => _ThinkingDots(t: _c.value),
                        ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // User avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AiColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.person_rounded,
                color: AiColors.textSub, size: 16),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  final double t;
  const _ThinkingDots({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = i / 3;
        final offset = math.sin((t + phase) * math.pi * 2).abs();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 6 + offset * 5,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4 + offset * 0.6),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── AI Thinking bubble (while AiService awaits) ──────────────────────────────

class _AiThinkingBubble extends StatefulWidget {
  const _AiThinkingBubble({super.key});

  @override
  State<_AiThinkingBubble> createState() => _AiThinkingBubbleState();
}

class _AiThinkingBubbleState extends State<_AiThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AiColors.buttonGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          // Thinking bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: AiColors.cardGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
              boxShadow: [
                BoxShadow(
                  color: AiColors.purple.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => _ThinkingDots(t: _c.value),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline bouncing dots (used inside _ChatBubble when isThinking=true)
class _InlineDots extends StatefulWidget {
  const _InlineDots();

  @override
  State<_InlineDots> createState() => _InlineDotsState();
}

class _InlineDotsState extends State<_InlineDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => _ThinkingDots(t: _c.value),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _ChatBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            msg.isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.isAi) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AiColors.buttonGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isAi
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: msg.isAi
                        ? AiColors.cardGradient
                        : const LinearGradient(
                            colors: [AiColors.purple, AiColors.purpleDark]),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.isAi ? 4 : 16),
                      bottomRight: Radius.circular(msg.isAi ? 16 : 4),
                    ),
                    border: msg.isAi
                        ? Border.all(color: Colors.white.withOpacity(0.07))
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: (msg.isAi
                                ? AiColors.purple
                                : AiColors.purpleDark)
                            .withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: msg.isThinking
                      ? const _InlineDots()
                      : Text(
                          msg.text,
                          style: const TextStyle(
                              color: AiColors.textWhite,
                              fontSize: 13.5,
                              height: 1.5),
                        ),
                ),
                // Source badge (live = Gemini/OpenAI, false = smart fallback)
                if (msg.isAi && msg.text.isNotEmpty) ...[  
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: msg.isLive
                              ? AiColors.purple.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: msg.isLive
                                ? AiColors.purple.withOpacity(0.4)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              msg.isLive
                                  ? Icons.cloud_done_rounded
                                  : Icons.offline_bolt_rounded,
                              size: 9,
                              color: msg.isLive
                                  ? AiColors.purpleLight
                                  : AiColors.textHint,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              msg.isLive ? 'Gemini' : 'Offline',
                              style: TextStyle(
                                fontSize: 9,
                                color: msg.isLive
                                    ? AiColors.purpleLight
                                    : AiColors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (msg.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: msg.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          msg.imageUrls[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AiColors.purple, AiColors.magenta],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.image_rounded,
                                color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!msg.isAi) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AiColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AiColors.textSub, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab chip ──────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AiColors.buttonGradient : null,
          color: selected ? null : AiColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withOpacity(0.08),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AiColors.purple.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? Colors.white : AiColors.textHint, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AiColors.textHint,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
