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

sealed class _Triple<A, B, C> {
  const _Triple();
}

final class _Value1<A, B, C> extends _Triple<A, B, C> {
  final A a;

  const _Value1(this.a);
}

final class _Value2<A, B, C> extends _Triple<A, B, C> {
  final B b;

  const _Value2(this.b);
}

final class _Value3<A, B, C> extends _Triple<A, B, C> {
  final C c;

  const _Value3(this.c);
}

void _ignore(Object? val) {}

void _panic(ThrownError error) {
  scheduleMicrotask(() {
    Error.throwWithStackTrace(
      error.error,
      error.stackTrace,
    );
  });
}
