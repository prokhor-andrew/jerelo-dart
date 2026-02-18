part of '../../cont.dart';

extension ContFfExtension<E, F, A> on Cont<E, F, A> {
  /// Executes the continuation in a fire-and-forget manner.
  ///
  /// Runs the continuation without waiting for the result. Both success and
  /// failure outcomes are ignored. This is useful for side-effects that should
  /// run asynchronously without blocking or requiring error handling.
  ///
  /// - [env]: The environment value to provide as context during execution.
  /// - [onPanic]: Callback invoked when a fatal, unrecoverable error occurs.
  ///   Defaults to re-throwing inside a microtask.
  void ff(
    E env, {
    void Function(ThrownError error) onPanic = _panic,
  }) {
    _run(
      ContRuntime._(env, () {
        return false;
      }, onPanic),
      ContObserver._((_) {}, (_) {}),
    );
  }
}
