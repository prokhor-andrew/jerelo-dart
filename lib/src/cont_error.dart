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
  const ContError(this.error, this.stackTrace);
}
