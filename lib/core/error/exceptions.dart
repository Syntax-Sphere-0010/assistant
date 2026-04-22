abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => message;
}

// Network Exceptions
class NetworkException extends AppException {
  const NetworkException({super.message = 'No internet connection.'});
}

class TimeoutException extends AppException {
  const TimeoutException({super.message = 'Request timed out.'});
}

class ServerException extends AppException {
  const ServerException({super.message = 'Server error occurred.', super.code});
}

class BadRequestException extends AppException {
  const BadRequestException({super.message = 'Bad request.', super.code});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({super.message = 'Unauthorized access.', super.code});
}

class ForbiddenException extends AppException {
  const ForbiddenException({super.message = 'Access forbidden.', super.code});
}

class NotFoundException extends AppException {
  const NotFoundException({super.message = 'Resource not found.', super.code});
}

class ValidationException extends AppException {
  const ValidationException({super.message = 'Validation failed.', super.code});
}

// Cache Exceptions
class CacheException extends AppException {
  const CacheException({super.message = 'Cache error occurred.'});
}

// Auth Exceptions
class AuthException extends AppException {
  const AuthException({super.message = 'Authentication error.', super.code});
}
