import 'package:jerelo/jerelo.dart';

extension ContElseMapExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms the termination error using a pure function.
  ///
  /// If the continuation terminates, applies the transformation function to
  /// the error value and terminates with the transformed error. This is useful
  /// for enriching or adapting error information.
  ///
  /// - [f]: Function that transforms the error value.
  Cont<E, F2, A> elseMap<F2>(
    F2 Function(F error) f,
  ) {
    return elseDo((error) {
      return Cont.error(f(error));
    });
  }

  /// Transforms the termination error using a zero-argument function.
  ///
  /// Similar to [elseMap] but replaces the error without examining the
  /// original error value.
  ///
  /// - [f]: Zero-argument function that produces a new error value.
  Cont<E, F2, A> elseMap0<F2>(F2 Function() f) {
    return elseMap((_) {
      return f();
    });
  }

  /// Transforms the termination error with access to both error and environment.
  ///
  /// Similar to [elseMap], but the transformation function receives both the
  /// error value and the environment. This is useful when error transformation
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and error value, and produces a transformed error.
  Cont<E, F2, A> elseMapWithEnv<F2>(
    F2 Function(E env, F error) f,
  ) {
    return Cont.askThen<E, F2>().thenDo((e) {
      return elseMap((error) {
        return f(e, error);
      });
    });
  }

  /// Transforms the termination error with access to the environment only.
  ///
  /// Similar to [elseMapWithEnv], but the transformation function only receives
  /// the environment and ignores the original error.
  ///
  /// - [f]: Function that takes the environment and produces a new error value.
  Cont<E, F2, A> elseMapWithEnv0<F2>(
    F2 Function(E env) f,
  ) {
    return elseMapWithEnv((e, _) {
      return f(e);
    });
  }

  /// Replaces the termination error with a fixed error value.
  ///
  /// If the continuation terminates, replaces the error with the provided value.
  /// This is the simplest form of error transformation.
  ///
  /// - [error]: The error value to replace with.
  Cont<E, F2, A> elseMapTo<F2>(F2 error) {
    return elseMap0(() {
      return error;
    });
  }
}
