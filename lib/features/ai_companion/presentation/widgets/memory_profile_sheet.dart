import 'package:flutter/material.dart';

import '../../data/memory_service.dart';
import '../../data/models/user_memory.dart';
import '../widgets/ai_theme_widgets.dart';

/// Bottom sheet for viewing and editing Gravity's memory about the user.
class MemoryProfileSheet extends StatefulWidget {
  final MemoryService memoryService;

  const MemoryProfileSheet({super.key, required this.memoryService});

  static Future<void> show(
    BuildContext context,
    MemoryService memoryService,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => MemoryProfileSheet(memoryService: memoryService),
    );
  }

  @override
  State<MemoryProfileSheet> createState() => _MemoryProfileSheetState();
}

class _MemoryProfileSheetState extends State<MemoryProfileSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _entry;
  late UserMemory _memory;

  // Text controllers for editable fields
  late TextEditingController _nameCtrl;
  final _goalCtrl    = TextEditingController();
  final _topicCtrl   = TextEditingController();
  final _factCtrl    = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    _memory = widget.memoryService.current;
    _nameCtrl = TextEditingController(text: _memory.name);
  }

  @override
  void dispose() {
    _entry.dispose();
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    _topicCtrl.dispose();
    _factCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await widget.memoryService.save(
      _memory.copyWith(name: _nameCtrl.text.trim()),
    );
    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addGoal() async {
    final val = _goalCtrl.text.trim();
    if (val.isEmpty) return;
    _goalCtrl.clear();
    setState(() {
      _memory = _memory.copyWith(goals: [..._memory.goals, val]);
    });
  }

  Future<void> _addTopic() async {
    final val = _topicCtrl.text.trim();
    if (val.isEmpty) return;
    _topicCtrl.clear();
    setState(() {
      _memory = _memory.copyWith(studyTopics: [..._memory.studyTopics, val]);
    });
  }

  Future<void> _addFact() async {
    final val = _factCtrl.text.trim();
    if (val.isEmpty) return;
    _factCtrl.clear();
    setState(() {
      _memory = _memory.copyWith(customFacts: [..._memory.customFacts, val]);
    });
  }

  void _removeGoal(String g) =>
      setState(() => _memory = _memory.copyWith(goals: _memory.goals.where((x) => x != g).toList()));

  void _removeTopic(String t) =>
      setState(() => _memory = _memory.copyWith(studyTopics: _memory.studyTopics.where((x) => x != t).toList()));

  void _removeFact(String f) =>
      setState(() => _memory = _memory.copyWith(customFacts: _memory.customFacts.where((x) => x != f).toList()));

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AiColors.surfaceLight,
        title: const Text('Clear Memory?', style: TextStyle(color: AiColors.textWhite)),
        content: const Text(
          'Gravity will forget everything about you. This cannot be undone.',
          style: TextStyle(color: AiColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AiColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.memoryService.clear();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (_, child) => FadeTransition(
        opacity: _entry,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: _buildSheet(),
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scroll) => CustomScrollView(
            controller: scroll,
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Sections ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildNameSection(),
                    const SizedBox(height: 20),
                    _buildListSection(
                      title: 'Goals & Exams',
                      icon: Icons.emoji_events_rounded,
                      color: AiColors.magenta,
                      items: _memory.goals,
                      controller: _goalCtrl,
                      hint: 'e.g. SBI PO, UPSC, MBA',
                      onAdd: _addGoal,
                      onRemove: _removeGoal,
                    ),
                    const SizedBox(height: 20),
                    _buildListSection(
                      title: 'Study Topics',
                      icon: Icons.menu_book_rounded,
                      color: AiColors.orbCyan,
                      items: _memory.studyTopics,
                      controller: _topicCtrl,
                      hint: 'e.g. Quantitative Aptitude',
                      onAdd: _addTopic,
                      onRemove: _removeTopic,
                    ),
                    const SizedBox(height: 20),
                    _buildListSection(
                      title: 'Other Facts',
                      icon: Icons.person_pin_rounded,
                      color: AiColors.purpleLight,
                      items: _memory.customFacts,
                      controller: _factCtrl,
                      hint: 'e.g. I am 22 years old',
                      onAdd: _addFact,
                      onRemove: _removeFact,
                    ),
                    const SizedBox(height: 24),

                    // Last updated
                    if (_memory.lastUpdated != null)
                      Center(
                        child: Text(
                          'Last updated: ${_formatDate(_memory.lastUpdated!)}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 11),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Clear button
                    GestureDetector(
                      onTap: _clearAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                size: 16, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text(
                              'Clear All Memory',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Brain icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AiColors.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memory',
                      style: TextStyle(
                        color: AiColors.textWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'What Gravity remembers about you',
                      style: TextStyle(
                        color: AiColors.textSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Save button
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AiColors.buttonGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: AiColors.purple.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return _SectionCard(
      title: 'Your Name',
      icon: Icons.badge_rounded,
      color: const Color(0xFF10B981),
      child: TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: AiColors.textWhite, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'e.g. Rahul Sharma',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    required void Function(String) onRemove,
  }) {
    return _SectionCard(
      title: title,
      icon: icon,
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chip list
          if (items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items
                  .map((item) => _MemoryChip(
                        label: item,
                        color: color,
                        onRemove: () => onRemove(item),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          // Add input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style:
                      const TextStyle(color: AiColors.textWhite, fontSize: 13),
                  onSubmitted: (_) => onAdd(),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_rounded, color: color, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} at ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AiColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Memory chip ───────────────────────────────────────────────────────────────

class _MemoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;

  const _MemoryChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, color: color, size: 13),
          ),
        ],
      ),
    );
  }
}
