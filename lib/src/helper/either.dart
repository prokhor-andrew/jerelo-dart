part of '../cont.dart';

/// Internal sum type representing one of two possible values.
///
/// Used throughout the helper implementations to represent branching results
/// (e.g., success vs. failure, continue vs. stop) without depending on
/// external packages.
sealed class _Either<A, B> {
  const _Either();
}

/// The left variant of [_Either], conventionally representing the first
/// alternative (e.g., "keep running" or "success value").
final class _Left<A, B> extends _Either<A, B> {
  final A value;

  const _Left(this.value);
}

/// The right variant of [_Either], conventionally representing the second
/// alternative (e.g., "stop" or "error list").
final class _Right<A, B> extends _Either<A, B> {
  final B value;

  const _Right(this.value);
}
