part of '../cont.dart';

/// Internal helper classes for representing either-or values.
///
/// These classes provide a simple sum type for internal use in the continuation
/// monad implementation.
sealed class _Either<A, B> {
  const _Either();
}

final class _Left<A, B> extends _Either<A, B> {
  final A value;

  const _Left(this.value);
}

final class _Right<A, B> extends _Either<A, B> {
  final B value;

  const _Right(this.value);
}
