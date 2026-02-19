part of '../../cont.dart';

extension ContElseForkExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// If the continuation terminates, starts the side-effect continuation without waiting
  /// for it to complete. Unlike [elseTap], this does not wait for the side-effect to
  /// finish before propagating the termination. Any error from the side-effect are
  /// silently ignored.
  ///
  /// - [f]: Function that returns a side-effect continuation.
  Cont<E, F, A> elseFork<F2, A2>(
    Cont<E, F2, A2> Function(ContError<F> error) f,
  ) {
    return _elseFork(this, f);
  }

  /// Executes a zero-argument side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// Similar to [elseFork] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> elseFork0<F2, A2>(
      Cont<E, F2, A2> Function() f) {
    return elseFork((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [elseFork], but the side-effect function receives both the error
  /// and the environment. The side-effect is started without waiting for it to complete,
  /// and any error from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the environment and error, and returns a side-effect continuation.
  Cont<E, F, A> elseForkWithEnv<F2, A2>(
    Cont<E, F2, A2> Function(E env, ContError<F> error) f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return elseFork<F2, A2>((error) {
        return f(e, error);
      });
    });
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [elseForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> elseForkWithEnv0<F2, A2>(
    Cont<E, F2, A2> Function(E env) f,
  ) {
    return elseForkWithEnv((e, _) {
      return f(e);
    });
  }
}
