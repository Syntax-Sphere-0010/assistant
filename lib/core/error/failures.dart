import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection.'});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message = 'Request timed out.'});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class BadRequestFailure extends Failure {
  const BadRequestFailure({required super.message, super.code});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Unauthorized. Please login again.'});
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.message = 'Access denied.'});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Resource not found.'});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Local data error.'});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'An unexpected error occurred.'});
}
