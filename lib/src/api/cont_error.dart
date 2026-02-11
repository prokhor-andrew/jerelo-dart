/// An immutable error container used throughout the continuation system.
///
/// Wraps an error object together with its stack trace, providing a consistent
/// way to propagate error information through continuation chains.
final class ContError {
  /// The error object that was caught or created.
  final Object error;

  /// The stack trace captured at the point where the error occurred.
  final StackTrace stackTrace;

  /// Creates an error wrapper containing an error and stack trace.
  ///
  /// - [error]: The error object to wrap.
  /// - [stackTrace]: The stack trace associated with the error.
  const ContError._(this.error, this.stackTrace);

  /// Creates an error wrapper from an error and an existing stack trace.
  ///
  /// Use this when you have already caught an error and its associated
  /// stack trace, for example inside a `catch` block.
  ///
  /// - [error]: The error object to wrap.
  /// - [st]: The stack trace associated with the error.
  static ContError withStackTrace(
    Object error,
    StackTrace st,
  ) {
    return ContError._(error, st);
  }

  /// Creates an error wrapper with an empty stack trace.
  ///
  /// Use this when the stack trace is not available or not relevant,
  /// for example when creating a logical termination reason that does
  /// not originate from a thrown exception.
  ///
  /// - [error]: The error object to wrap.
  static ContError withNoStackTrace(Object error) {
    return ContError._(error, StackTrace.empty);
  }

  /// Creates an error wrapper and captures the current stack trace.
  ///
  /// Use this when you want to create an error at the call site and
  /// automatically record where it was created.
  ///
  /// - [error]: The error object to wrap.
  static ContError capture(Object error) {
    return ContError._(error, StackTrace.current);
  }

  @override
  String toString() {
    return "{ error=$error, stackTrace=$stackTrace }";
  }
}
