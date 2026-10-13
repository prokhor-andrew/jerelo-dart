import 'package:jerelo/jerelo.dart';

extension ContDemoteExtension<E, F, A> on Cont<E, F, A> {
  /// Unconditionally demotes the value to the error channel.
  ///
  /// Takes a successful value and converts it into an error.
  /// This is useful for implementing validation logic where certain values
  /// should be treated as errors, or for custom error handling flows.
  ///
  /// - [f]: Function that computes the error from the value.
  Cont<E, F, A> demote(F Function(A value) f) {
    return thenDo((a) {
      final error = f(a);
      return Cont.error<E, F, A>(error);
    });
  }

  /// Demotes to error computed from a zero-argument function.
  ///
  /// Similar to [demote] but the error computation doesn't depend on the value.
  ///
  /// - [f]: Zero-argument function that computes the error.
  Cont<E, F, A> demote0(F Function() f) {
    return demote((_) {
      return f();
    });
  }

  /// Demotes to error computed from both value and environment.
  ///
  /// Similar to [demote], but the error computation function receives both the
  /// current value and the environment. This is useful when error creation needs
  /// access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and value, and computes the error.
  Cont<E, F, A> demoteWithEnv(
    F Function(E env, A value) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return demote((a) {
        return f(e, a);
      });
    });
  }

  /// Demotes to error computed from the environment only.
  ///
  /// Similar to [demoteWithEnv], but the error computation function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and computes the error.
  Cont<E, F, A> demoteWithEnv0(
    F Function(E env) f,
  ) {
    return demoteWithEnv((e, _) {
      return f(e);
    });
  }

  /// Demotes to a fixed error value.
  ///
  /// Replaces any successful value with the provided error.
  /// This is the simplest form of demotion.
  ///
  /// - [error]: The error to demote to.
  Cont<E, F, A> demoteWith(F error) {
    return demote0(() {
      return error;
    });
  }
}
