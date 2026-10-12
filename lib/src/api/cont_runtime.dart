part of '../cont.dart';

/// Provides runtime context for continuation execution.
///
/// [ContRuntime] carries the environment during the execution of a [Cont].
/// It allows continuations to access contextual information.
final class ContRuntime<E> {
  final E _env;

  const ContRuntime._(this._env);

  /// Returns the environment value of type [E].
  ///
  /// The environment provides contextual information such as configuration,
  /// dependencies, or any data that should flow through the continuation execution.
  E env() {
    return _env;
  }

  /// Creates a copy of this runtime with a different environment.
  ///
  /// Returns a new [ContRuntime] with the provided environment. This is used
  /// by [local] and related methods to modify the environment context.
  ///
  /// - [env]: The new environment value to use.
  ContRuntime<E2> copyUpdateEnv<E2>(E2 env) {
    return ContRuntime._(env);
  }
}
