part of '../../cont.dart';

extension ContThenTapExtension<E, F, A> on Cont<E, F, A> {
  /// Chains a side-effect continuation while preserving the original value.
  ///
  /// Executes a continuation for its side effects, then returns the original value.
  ///
  /// - [f]: Side-effect function that returns a continuation.
  Cont<E, F, A> thenTap<A2>(
      Cont<E, F, A2> Function(A value) f) {
    return thenDo((a) {
      Cont<E, F, A2> contA2 = f(a);
      if (contA2 is Cont<E, F, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      return contA2.thenMapTo(a);
    });
  }

  /// Chains a zero-argument side-effect continuation.
  ///
  /// Similar to [thenTap] but with a zero-argument function.
  ///
  /// - [f]: Zero-argument side-effect function.
  Cont<E, F, A> thenTap0<A2>(Cont<E, F, A2> Function() f) {
    return thenTap((_) {
      return f();
    });
  }

  /// Chains a side-effect continuation with access to both the environment and value.
  ///
  /// Similar to [thenTap], but the side-effect function receives both the current
  /// value and the environment. After executing the side-effect, returns the original
  /// value. This is useful for logging, monitoring, or other side-effects that need
  /// access to both the value and configuration context.
  ///
  /// - [f]: Function that takes the environment and value, and returns a side-effect continuation.
  Cont<E, F, A> thenTapWithEnv<A2>(
    Cont<E, F, A2> Function(E env, A a) f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return thenTap((a) {
        return f(e, a);
      });
    });
  }

  /// Chains a side-effect continuation with access to the environment only.
  ///
  /// Similar to [thenTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the current value. After executing the side-effect,
  /// returns the original value.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> thenTapWithEnv0<A2>(
    Cont<E, F, A2> Function(E env) f,
  ) {
    return thenTapWithEnv((e, _) {
      return f(e);
    });
  }
}
