part of '../../cont.dart';

extension ContRunExtension<E, A> on Cont<E, A> {
  /// Executes the continuation with separate callbacks for termination and value.
  ///
  /// Initiates execution of the continuation with separate handlers for success
  /// and failure cases. All callbacks are optional and default to no-op,
  /// allowing callers to subscribe only to the channels they care about.
  ///
  /// Returns a [ContCancelToken] that can be used to cooperatively cancel the
  /// execution. Calling [ContCancelToken.cancel] sets an internal flag that
  /// the runtime polls via `isCancelled()`. The token also exposes
  /// [ContCancelToken.isCancelled] to query the current cancellation state.
  /// Calling [ContCancelToken.cancel] multiple times is safe but has no
  /// additional effect.
  ///
  /// - [env]: The environment value to provide as context during execution.
  /// - [onPanic]: Callback invoked when a fatal, unrecoverable error occurs
  ///   (e.g. an observer callback throws). Defaults to re-throwing inside a
  ///   microtask.
  /// - [onTerminate]: Callback invoked when the continuation terminates with
  ///   errors. Defaults to ignoring the errors.
  /// - [onValue]: Callback invoked when the continuation produces a successful
  ///   value. Defaults to ignoring the value.
  ContCancelToken run(
    E env, {
    void Function(ContError fatal) onPanic = _panic,
    void Function(List<ContError> errors) onTerminate =
        _ignore,
    void Function(A value) onValue = _ignore,
  }) {
    final cancelToken = ContCancelToken._();

    _run(
      ContRuntime._(env, cancelToken.isCancelled, onPanic),
      ContObserver._(onTerminate, onValue),
    );

    // returns cancel token
    return cancelToken;
  }
}
