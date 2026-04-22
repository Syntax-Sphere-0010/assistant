import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:my_flutter_app/core/error/failures.dart';
import 'package:my_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_flutter_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:my_flutter_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:my_flutter_app/features/auth/presentation/bloc/auth_bloc.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late MockLoginUseCase mockLoginUseCase;
  late MockRegisterUseCase mockRegisterUseCase;
  late AuthBloc authBloc;

  final testUser = UserEntity(
    id: 'test-id',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: DateTime(2024, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(
      const LoginParams(email: '', password: ''),
    );
    registerFallbackValue(
      const RegisterParams(name: '', email: '', password: ''),
    );
  });

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockRegisterUseCase = MockRegisterUseCase();
    authBloc = AuthBloc(mockLoginUseCase, mockRegisterUseCase);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitialState', () {
      expect(authBloc.state, const AuthInitialState());
    });

    group('AuthLoginEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [Loading, Authenticated] when login succeeds',
        build: () {
          when(() => mockLoginUseCase(any()))
              .thenAnswer((_) async => Right(testUser));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginEvent(
          email: 'test@example.com',
          password: 'password123',
        )),
        expect: () => [
          const AuthLoadingState(),
          AuthAuthenticatedState(user: testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [Loading, Error] when login fails',
        build: () {
          when(() => mockLoginUseCase(any())).thenAnswer(
            (_) async => const Left(
              UnauthorizedFailure(message: 'Invalid credentials'),
            ),
          );
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginEvent(
          email: 'test@example.com',
          password: 'wrongpassword',
        )),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Invalid credentials'),
        ],
      );
    });

    group('AuthLogoutEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [Loading, Unauthenticated] on logout',
        build: () => authBloc,
        act: (bloc) => bloc.add(const AuthLogoutEvent()),
        expect: () => [
          const AuthLoadingState(),
          const AuthUnauthenticatedState(),
        ],
      );
    });
  });
}
