part of '../cont.dart';

/// No-op callback that ignores any value. Used as the default for optional
/// observer callbacks.
void _ignore(Object? val) {}

/// Default panic handler that re-throws the error inside a microtask so it
/// surfaces as an unhandled exception.
void _panic(ContError error) {
  scheduleMicrotask(() {
    Error.throwWithStackTrace(
      error.error,
      error.stackTrace,
    );
  });
}
