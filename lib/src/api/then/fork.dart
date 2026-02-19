part of '../../cont.dart';

extension ContThenForkExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation in a fire-and-forget manner.
  ///
  /// Unlike [thenTap], this method does not wait for the side-effect to complete.
  /// The side-effect continuation is started immediately, and the original value
  /// is returned without delay. Any errors from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the current value and returns a side-effect continuation.
  Cont<E, F, A> thenFork<F2, A2>(
      Cont<E, F2, A2> Function(A a) f) {
    return _thenFork(this, f);
  }

  /// Executes a zero-argument side-effect continuation in a fire-and-forget manner.
  ///
  /// Similar to [thenFork] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> thenFork0<F2, A2>(
      Cont<E, F2, A2> Function() f) {
    return thenFork((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [thenFork], but the side-effect function receives both the current
  /// value and the environment. The side-effect is started immediately without waiting,
  /// and any errors are silently ignored.
  ///
  /// - [f]: Function that takes the environment and value, and returns a side-effect continuation.
  Cont<E, F, A> thenForkWithEnv<F2, A2>(
    Cont<E, F2, A2> Function(E env, A a) f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return thenFork((a) {
        return f(e, a);
      });
    });
  }

  /// Executes a side-effect continuation in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [thenForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> thenForkWithEnv0<F2, A2>(
    Cont<E, F2, A2> Function(E env) f,
  ) {
    return thenForkWithEnv((e, _) {
      return f(e);
    });
  }
}
