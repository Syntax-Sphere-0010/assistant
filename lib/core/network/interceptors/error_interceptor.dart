import 'package:dio/dio.dart';

import '../../error/exceptions.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw TimeoutException(
          message: 'Connection timed out. Please check your internet connection.',
        );

      case DioExceptionType.connectionError:
        throw NetworkException(
          message: 'No internet connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final message = _extractErrorMessage(err.response?.data);

        switch (statusCode) {
          case 400:
            throw BadRequestException(message: message);
          case 401:
            throw UnauthorizedException(message: message);
          case 403:
            throw ForbiddenException(message: message);
          case 404:
            throw NotFoundException(message: message);
          case 422:
            throw ValidationException(message: message);
          case 500:
          case 502:
          case 503:
            throw ServerException(message: message);
          default:
            throw ServerException(message: message);
        }

      default:
        throw ServerException(
          message: err.message ?? 'An unexpected error occurred.',
        );
    }
  }

  String _extractErrorMessage(dynamic data) {
    if (data == null) return 'An error occurred.';
    if (data is String) return data;
    if (data is Map) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          'An error occurred.';
    }
    return 'An error occurred.';
  }
}
