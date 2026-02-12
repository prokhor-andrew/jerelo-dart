part of '../../cont.dart';

extension ContAbortExtension<E, A> on Cont<E, A> {
  /// Unconditionally terminates the continuation with computed errors.
  ///
  /// Takes a successful value and converts it into a termination with errors.
  /// This is useful for implementing validation logic where certain values
  /// should cause termination, or for custom error handling flows.
  ///
  /// - [f]: Function that computes the error list from the value.
  Cont<E, A> abort(List<ContError> Function(A value) f) {
    return thenDo((a) {
      final errors = f(a);
      return Cont.stop<E, A>(errors);
    });
  }

  /// Unconditionally terminates with errors computed from a zero-argument function.
  ///
  /// Similar to [abort] but the error computation doesn't depend on the value.
  ///
  /// - [f]: Zero-argument function that computes the error list.
  Cont<E, A> abort0(List<ContError> Function() f) {
    return abort((_) {
      return f();
    });
  }

  /// Unconditionally terminates with errors computed from both value and environment.
  ///
  /// Similar to [abort], but the error computation function receives both the
  /// current value and the environment. This is useful when error creation needs
  /// access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and value, and computes the error list.
  Cont<E, A> abortWithEnv(
    List<ContError> Function(E env, A value) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return abort((a) {
        return f(e, a);
      });
    });
  }

  /// Unconditionally terminates with errors computed from the environment only.
  ///
  /// Similar to [abortWithEnv], but the error computation function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and computes the error list.
  Cont<E, A> abortWithEnv0(
    List<ContError> Function(E env) f,
  ) {
    return abortWithEnv((e, _) {
      return f(e);
    });
  }

  /// Unconditionally terminates with a fixed list of errors.
  ///
  /// Replaces any successful value with a termination containing the
  /// provided errors. This is the simplest form of forced termination.
  ///
  /// - [errors]: The error list to terminate with.
  Cont<E, A> abortWith(List<ContError> errors) {
    errors = errors.toList(); // defensive copy
    return abort0(() {
      return errors;
    });
  }
}
