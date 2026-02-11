part of '../../cont.dart';

extension ContThenMapExtension<E, A> on Cont<E, A> {
  /// Transforms the value inside a [Cont] using a pure function.
  ///
  /// Applies a function to the successful value of the continuation without
  /// affecting the termination case.
  ///
  /// - [f]: Transformation function to apply to the value.
  Cont<E, A2> thenMap<A2>(A2 Function(A value) f) {
    return thenDo((a) {
      final a2 = f(a);
      return Cont.of(a2);
    });
  }

  /// Transforms the value inside a [Cont] using a zero-argument function.
  ///
  /// Similar to [thenMap] but ignores the current value and computes a new one.
  ///
  /// - [f]: Zero-argument transformation function.
  Cont<E, A2> thenMap0<A2>(A2 Function() f) {
    return thenMap((_) {
      return f();
    });
  }

  Cont<E, A2> thenMapWithEnv<A2>(
    A2 Function(E env, A value) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenMap((a) {
        return f(e, a);
      });
    });
  }

  Cont<E, A2> thenMapWithEnv0<A2>(A2 Function(E env) f) {
    return thenMapWithEnv((e, _) {
      return f(e);
    });
  }

  /// Replaces the value inside a [Cont] with a constant.
  ///
  /// Discards the current value and replaces it with a fixed value.
  ///
  /// - [value]: The constant value to replace with.
  Cont<E, A2> thenMapTo<A2>(A2 value) {
    return thenMap0(() {
      return value;
    });
  }
}
