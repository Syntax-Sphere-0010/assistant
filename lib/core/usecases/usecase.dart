import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// Base use case interface for use cases with parameters
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Base use case interface for use cases without parameters
abstract class NoParamsUseCase<Type> {
  Future<Either<Failure, Type>> call();
}

/// Use case for stream-based operations
abstract class StreamUseCase<Type, Params> {
  Stream<Either<Failure, Type>> call(Params params);
}

/// Empty params class for use cases that don't need parameters
class NoParams {
  const NoParams();
}
