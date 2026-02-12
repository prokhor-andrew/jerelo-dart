part of '../../cont.dart';

extension ContElseMapExtension<E, A> on Cont<E, A> {
  /// Transforms termination errors using a pure function.
  ///
  /// If the continuation terminates, applies the transformation function to
  /// the error list and terminates with the transformed errors. This is useful
  /// for enriching, filtering, or transforming error information.
  ///
  /// - [f]: Function that transforms the error list.
  Cont<E, A> elseMap(
    List<ContError> Function(List<ContError> errors) f,
  ) {
    return elseDo((errors) {
      return Cont.stop<E, A>(f(errors));
    });
  }

  /// Transforms termination errors using a zero-argument function.
  ///
  /// Similar to [elseMap] but replaces errors without examining the original
  /// error list.
  ///
  /// - [f]: Zero-argument function that produces new errors.
  Cont<E, A> elseMap0(List<ContError> Function() f) {
    return elseMap((_) {
      return f();
    });
  }

  /// Transforms termination errors with access to both errors and environment.
  ///
  /// Similar to [elseMap], but the transformation function receives both the
  /// error list and the environment. This is useful when error transformation
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and errors, and produces transformed errors.
  Cont<E, A> elseMapWithEnv(
    List<ContError> Function(E env, List<ContError> errors)
    f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseMap((errors) {
        return f(e, errors);
      });
    });
  }

  /// Transforms termination errors with access to the environment only.
  ///
  /// Similar to [elseMapWithEnv], but the transformation function only receives
  /// the environment and ignores the original errors.
  ///
  /// - [f]: Function that takes the environment and produces new errors.
  Cont<E, A> elseMapWithEnv0(
    List<ContError> Function(E env) f,
  ) {
    return elseMapWithEnv((e, _) {
      return f(e);
    });
  }

  /// Replaces termination errors with a fixed error list.
  ///
  /// If the continuation terminates, replaces the errors with the provided list.
  /// This is the simplest form of error transformation.
  ///
  /// - [errors]: The error list to replace with.
  Cont<E, A> elseMapTo(List<ContError> errors) {
    errors = errors.toList(); // defensive copy
    return elseMap0(() {
      return errors;
    });
  }
}
