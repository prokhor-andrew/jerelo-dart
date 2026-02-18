part of '../../cont.dart';

extension ContThenZipExtension<E, F, A> on Cont<E, F, A> {
  /// Chains and combines two continuation values.
  ///
  /// Sequences two continuations and combines their results using the provided function.
  ///
  /// - [f]: Function to produce the second continuation from the first value.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, F, A3> thenZip<A2, A3>(
    Cont<E, F, A2> Function(A value) f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return thenDo((a1) {
      Cont<E, F, A2> contA2 = f(a1);
      if (contA2 is Cont<E, F, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      return contA2.thenMap((a2) {
        return combine(a1, a2);
      });
    });
  }

  /// Chains and combines with a zero-argument function.
  ///
  /// Similar to [thenZip] but the second continuation doesn't depend
  /// on the first value.
  ///
  /// - [f]: Zero-argument function to produce the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, F, A3> thenZip0<A2, A3>(
    Cont<E, F, A2> Function() f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return thenZip((_) {
      return f();
    }, combine);
  }

  /// Chains and combines two continuations with access to the environment.
  ///
  /// Similar to [thenZip], but the function producing the second continuation
  /// receives both the current value and the environment. This is useful when
  /// the second computation needs access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and value, and produces the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, F, A3> thenZipWithEnv<A2, A3>(
    Cont<E, F, A2> Function(E env, A value) f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return thenZip((a1) {
        return f(e, a1);
      }, combine);
    });
  }

  /// Chains and combines with a continuation that has access to the environment only.
  ///
  /// Similar to [thenZipWithEnv], but the function producing the second continuation
  /// only receives the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and produces the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, F, A3> thenZipWithEnv0<A2, A3>(
    Cont<E, F, A2> Function(E env) f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return thenZipWithEnv((e, _) {
      return f(e);
    }, combine);
  }
}
