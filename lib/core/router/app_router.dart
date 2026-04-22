import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/ai_companion/presentation/pages/ai_onboarding_page.dart';
import '../../features/ai_companion/presentation/pages/ai_home_page.dart';
import '../../features/ai_companion/presentation/pages/ai_chat_page.dart';
import '../../features/ai_companion/presentation/widgets/ai_theme_widgets.dart';
import '../constants/route_constants.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteConstants.aiOnboarding, // Start on AI screens
    debugLogDiagnostics: true,
    routes: [
      // ── AI Companion ──────────────────────────────────────────────
      GoRoute(
        path: RouteConstants.aiOnboarding,
        name: RouteConstants.aiOnboardingName,
        builder: (context, state) => const AiOnboardingPage(),
      ),
      GoRoute(
        path: RouteConstants.aiHome,
        name: RouteConstants.aiHomeName,
        builder: (context, state) => const AiHomePage(),
      ),
      GoRoute(
        path: RouteConstants.aiChat,
        name: RouteConstants.aiChatName,
        builder: (context, state) => const AiChatPage(),
      ),

      // ── Auth ──────────────────────────────────────────────────────
      GoRoute(
        path: RouteConstants.splash,
        name: RouteConstants.splashName,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: RouteConstants.login,
        name: RouteConstants.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteConstants.register,
        name: RouteConstants.registerName,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteConstants.home,
        name: RouteConstants.homeName,
        builder: (context, state) => const HomePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AiColors.background,
      body: Center(
        child: Text(
          'Page not found: ${state.error}',
          style: const TextStyle(color: AiColors.textWhite),
        ),
      ),
    ),
  );
}

