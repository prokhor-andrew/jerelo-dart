part of '../cont.dart';

void _ignore(val) {}

bool _false() => false;

void _panic(ContError error) {
  scheduleMicrotask(() {
    Error.throwWithStackTrace(
      error.error,
      error.stackTrace,
    );
  });
}
