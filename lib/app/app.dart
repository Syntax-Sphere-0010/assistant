import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/wake_word/data/wake_word_service.dart';
import '../features/wake_word/presentation/bloc/wake_word_bloc.dart';
import '../core/di/injection.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthCheckStatusEvent()),
        ),
        BlocProvider<WakeWordBloc>(
          create: (_) => WakeWordBloc(WakeWordService()),
          lazy: false, // Start immediately so background detection is ready
        ),
      ],
      child: MaterialApp.router(
        title: 'Gravity Assistant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}

