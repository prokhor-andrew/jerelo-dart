part of '../cont.dart';

/// Provides runtime context for continuation execution.
///
/// [ContRuntime] encapsulates the environment and cancellation state during
/// the execution of a [Cont]. It allows continuations to access contextual
/// information and check for cancellation.
final class ContRuntime<E> {
  final E _env;

  /// Function that checks whether the continuation execution has been cancelled.
  ///
  /// Returns `true` if the execution should be stopped, `false` otherwise.
  /// Continuations should check this regularly to support cooperative cancellation.
  final bool Function() isCancelled;

  const ContRuntime._(
    this._env,
    this.isCancelled,
  );

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
  /// the cancellation function. This is used by [local] and related methods
  /// to modify the environment context.
  ///
  /// - [env]: The new environment value to use.
  ContRuntime<E2> copyUpdateEnv<E2>(E2 env) {
    return ContRuntime._(env, isCancelled);
  }

  /// Creates a copy of this runtime with an additional cancellation source.
  ///
  /// Returns a new [ContRuntime] whose [isCancelled] returns `true` if either
  /// the original cancellation function or [anotherIsCancelled] returns `true`.
  /// Used internally to compose independent cancellation tokens when running
  /// continuations in parallel.
  ///
  /// - [anotherIsCancelled]: Additional cancellation predicate to combine with
  ///   the existing one.
  ContRuntime<E> extendCancellation(
    bool Function() anotherIsCancelled,
  ) {
    return ContRuntime._(_env, () {
      return isCancelled() || anotherIsCancelled();
    });
  }
}
