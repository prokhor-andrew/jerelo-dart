part of '../../cont.dart';

extension ContAbortExtension<E, F, A> on Cont<E, F, A> {
  /// Unconditionally terminates the continuation with computed error.
  ///
  /// Takes a successful value and converts it into a termination with error.
  /// This is useful for implementing validation logic where certain values
  /// should cause termination, or for custom error handling flows.
  ///
  /// - [f]: Function that computes the error list from the value.
  Cont<E, F, A> abort(ContError<F> Function(A value) f) {
    return thenDo((a) {
      final error = f(a);
      return Cont.stop<E, F, A>(error);
    });
  }

  /// Unconditionally terminates with error computed from a zero-argument function.
  ///
  /// Similar to [abort] but the error computation doesn't depend on the value.
  ///
  /// - [f]: Zero-argument function that computes the error list.
  Cont<E, F, A> abort0(ContError<F> Function() f) {
    return abort((_) {
      return f();
    });
  }

  /// Unconditionally terminates with error computed from both value and environment.
  ///
  /// Similar to [abort], but the error computation function receives both the
  /// current value and the environment. This is useful when error creation needs
  /// access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and value, and computes the error list.
  Cont<E, F, A> abortWithEnv(
    ContError<F> Function(E env, A value) f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return abort((a) {
        return f(e, a);
      });
    });
  }

  /// Unconditionally terminates with error computed from the environment only.
  ///
  /// Similar to [abortWithEnv], but the error computation function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and computes the error list.
  Cont<E, F, A> abortWithEnv0(
    ContError<F> Function(E env) f,
  ) {
    return abortWithEnv((e, _) {
      return f(e);
    });
  }

  /// Unconditionally terminates with a fixed list of error.
  ///
  /// Replaces any successful value with a termination containing the
  /// provided error. This is the simplest form of forced termination.
  ///
  /// - [error]: The error list to terminate with.
  Cont<E, F, A> abortWith(ContError<F> error) {
    return abort0(() {
      return error;
    });
  }
}
