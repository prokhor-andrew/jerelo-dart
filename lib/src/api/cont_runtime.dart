part of '../cont.dart';

/// Provides runtime context for continuation execution.
///
/// [ContRuntime] encapsulates the environment and cancellation state during
/// the execution of a [Cont]. It allows continuations to access contextual
/// information, check for cancellation, and react to it.
final class ContRuntime<E> {
  final E _env;

  final _CancelNode _cancellation;

  /// Callback invoked when a fatal, unrecoverable error occurs during
  /// continuation execution.
  ///
  /// Unlike [ContObserver.onElse], which handles expected termination
  /// errors within the normal control flow, [onPanic] is reserved for
  /// situations that violate internal invariants (e.g. an observer callback
  /// throwing an exception). The default implementation re-throws the error
  /// inside a microtask so it surfaces as an unhandled exception.
  final void Function(ContError fatal) onPanic;

  const ContRuntime._(
    this._env,
    this._cancellation,
    this.onPanic,
  );

  /// Checks whether the continuation execution has been cancelled.
  ///
  /// Returns `true` if the execution should be stopped, `false` otherwise.
  /// Continuations should check this regularly to support cooperative cancellation.
  bool isCancelled() {
    return _cancellation.isCancelled();
  }

  /// Registers [callback] to run when this execution is cancelled.
  ///
  /// Use it for work that cannot poll [isCancelled], such as releasing a
  /// resource or aborting a pending request while waiting for it. If the
  /// execution is already cancelled, [callback] runs immediately.
  ///
  /// Callbacks run once, in reverse order of registration. An exception
  /// thrown by a callback goes to the `onPanic` handler of [Cont.run] and
  /// does not stop the remaining callbacks.
  ///
  /// Returns a function that unregisters [callback]. Call it once the
  /// callback is no longer needed, for example when the work completes
  /// normally.
  void Function() onCancel(void Function() callback) {
    return _cancellation.onCancel(callback);
  }

  /// Creates a child runtime with its own cancellation.
  ///
  /// The returned `runtime` is cancelled when this runtime is cancelled, or
  /// when the returned `cancel` function is called. In both cases the
  /// callbacks registered on it with [onCancel] run, so work started under
  /// it (for example a [Cont.bracket]) can react immediately.
  ///
  /// Use it to stop part of a computation on a local condition, such as a
  /// deadline, while still following the parent's cancellation. Call
  /// `cancel` once that part is no longer needed.
  ({ContRuntime<E> runtime, void Function() cancel})
      withCancellation() {
    final node = _CancelNode._child(_cancellation);
    return (
      runtime: ContRuntime._(_env, node, onPanic),
      cancel: node.cancel,
    );
  }

  /// Returns the environment value of type [E].
  ///
  /// The environment provides contextual information such as configuration,
  /// dependencies, or any data that should flow through the continuation execution.
  E env() {
    return _env;
  }

  /// Creates a copy of this runtime with a different environment.
  ///
  /// Returns a new [ContRuntime] with the provided environment while preserving
  /// the cancellation scope. This is used by [local] and related methods
  /// to modify the environment context.
  ///
  /// - [env]: The new environment value to use.
  ContRuntime<E2> copyUpdateEnv<E2>(E2 env) {
    return ContRuntime._(env, _cancellation, onPanic);
  }

  /// Returns a runtime with the same environment that is never cancelled.
  ContRuntime<E> _uncancellable() {
    return ContRuntime._(
        _env, _CancelNode._root(), onPanic);
  }
}
