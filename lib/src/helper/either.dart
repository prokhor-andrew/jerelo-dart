part of '../cont.dart';

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
