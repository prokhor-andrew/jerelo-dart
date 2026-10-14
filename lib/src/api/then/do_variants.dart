import 'package:jerelo/jerelo.dart';

extension ContThenDoVariantsExtension<E, F, A>
    on Cont<E, F, A> {
  /// Chains a [Cont]-returning zero-argument function.
  ///
  /// Similar to [thenDo] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a continuation.
  Cont<E, F, A2> thenDo0<A2>(Cont<E, F, A2> Function() f) {
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
  Cont<E, F, A2> thenDoWithEnv<A2>(
    Cont<E, F, A2> Function(E env, A a) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
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
  Cont<E, F, A2> thenDoWithEnv0<A2>(
    Cont<E, F, A2> Function(E env) f,
  ) {
    return thenDoWithEnv((e, _) {
      return f(e);
    });
  }
}
