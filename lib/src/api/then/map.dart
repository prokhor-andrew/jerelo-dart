import 'package:jerelo/jerelo.dart';

extension ContThenMapExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms the value inside a [Cont] using a pure function.
  ///
  /// Applies a function to the successful value of the continuation without
  /// affecting the termination case.
  ///
  /// - [f]: Transformation function to apply to the value.
  Cont<E, F, A2> thenMap<A2>(A2 Function(A value) f) {
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
  Cont<E, F, A2> thenMap0<A2>(A2 Function() f) {
    return thenMap((_) {
      return f();
    });
  }

  /// Transforms the value with access to both the value and environment.
  ///
  /// Similar to [thenMap], but the transformation function receives both the
  /// current value and the environment. This is useful when the transformation
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and value, and returns a new value.
  Cont<E, F, A2> thenMapWithEnv<A2>(
    A2 Function(E env, A value) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return thenMap((a) {
        return f(e, a);
      });
    });
  }

  /// Transforms the value with access to the environment only.
  ///
  /// Similar to [thenMapWithEnv], but the transformation function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and returns a new value.
  Cont<E, F, A2> thenMapWithEnv0<A2>(A2 Function(E env) f) {
    return thenMapWithEnv((e, _) {
      return f(e);
    });
  }

  /// Replaces the value inside a [Cont] with a constant.
  ///
  /// Discards the current value and replaces it with a fixed value.
  ///
  /// - [value]: The constant value to replace with.
  Cont<E, F, A2> thenMapTo<A2>(A2 value) {
    return thenMap0(() {
      return value;
    });
  }
}
