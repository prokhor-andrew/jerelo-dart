part of '../../cont.dart';

extension ContThenDoExtension<E, A> on Cont<E, A> {
  /// Chains a [Cont]-returning function to create dependent computations.
  ///
  /// Monadic bind operation. Sequences continuations where the second depends
  /// on the result of the first.
  ///
  /// - [f]: Function that takes a value and returns a continuation.
  Cont<E, A2> thenDo<A2>(Cont<E, A2> Function(A value) f) {
    return _thenDo(this, f);
  }

  /// Chains a [Cont]-returning zero-argument function.
  ///
  /// Similar to [thenDo] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a continuation.
  Cont<E, A2> thenDo0<A2>(Cont<E, A2> Function() f) {
    return thenDo((_) {
      return f();
    });
  }

  /// Chains a continuation-returning function that has access to both the value and environment.
  ///
  /// Similar to [thenDo], but the function receives both the current value and the
  /// environment. This is useful when the next computation needs access to
  /// configuration or context from the environment.
  ///
  /// - [f]: Function that takes the environment and value, and returns a continuation.
  Cont<E, A2> thenDoWithEnv<A2>(
    Cont<E, A2> Function(E env, A a) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenDo((a) {
        return f(e, a);
      });
    });
  }

  /// Chains a continuation-returning function with access to the environment only.
  ///
  /// Similar to [thenDoWithEnv], but the function only receives the environment
  /// and ignores the current value. This is useful when the next computation needs
  /// access to configuration or context but doesn't depend on the previous value.
  ///
  /// - [f]: Function that takes the environment and returns a continuation.
  Cont<E, A2> thenDoWithEnv0<A2>(
    Cont<E, A2> Function(E env) f,
  ) {
    return thenDoWithEnv((e, _) {
      return f(e);
    });
  }
}
