import 'package:jerelo/jerelo.dart';

extension ContElseMapExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms termination error using a pure function.
  ///
  /// If the continuation terminates, applies the transformation function to
  /// the error list and terminates with the transformed error. This is useful
  /// for enriching, filtering, or transforming error information.
  ///
  /// - [f]: Function that transforms the error list.
  Cont<E, F2, A> elseMap<F2>(
    F2 Function(F error) f,
  ) {
    return elseDo((error) {
      return Cont.error(f(error));
    });
  }

  /// Transforms termination error using a zero-argument function.
  ///
  /// Similar to [elseMap] but replaces error without examining the original
  /// error list.
  ///
  /// - [f]: Zero-argument function that produces new error.
  Cont<E, F2, A> elseMap0<F2>(F2 Function() f) {
    return elseMap((_) {
      return f();
    });
  }

  /// Transforms termination error with access to both error and environment.
  ///
  /// Similar to [elseMap], but the transformation function receives both the
  /// error list and the environment. This is useful when error transformation
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and error, and produces transformed error.
  Cont<E, F2, A> elseMapWithEnv<F2>(
    F2 Function(E env, F error) f,
  ) {
    return Cont.askThen<E, F2>().thenDo((e) {
      return elseMap((error) {
        return f(e, error);
      });
    });
  }

  /// Transforms termination error with access to the environment only.
  ///
  /// Similar to [elseMapWithEnv], but the transformation function only receives
  /// the environment and ignores the original error.
  ///
  /// - [f]: Function that takes the environment and produces new error.
  Cont<E, F2, A> elseMapWithEnv0<F2>(
    F2 Function(E env) f,
  ) {
    return elseMapWithEnv((e, _) {
      return f(e);
    });
  }

  /// Replaces termination error with a fixed error list.
  ///
  /// If the continuation terminates, replaces the error with the provided list.
  /// This is the simplest form of error transformation.
  ///
  /// - [error]: The error list to replace with.
  Cont<E, F2, A> elseMapTo<F2>(F2 error) {
    return elseMap0(() {
      return error;
    });
  }
}
