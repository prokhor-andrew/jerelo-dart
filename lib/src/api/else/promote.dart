import 'package:jerelo/jerelo.dart';

extension ContPromoteExtension<E, F, A> on Cont<E, F, A> {
  /// Promotes an error to the success channel by computing a replacement value.
  ///
  /// If the continuation terminates with an error, applies [f] to the error
  /// and succeeds with the returned value. This is a convenience over [elseDo]
  /// for cases where the promotion logic is a pure function rather than a
  /// full continuation.
  ///
  /// - [f]: Function that receives the error and returns a success value.
  Cont<E, F, A> promote(A Function(F error) f) {
    return elseDo((error) {
      final a = f(error);
      return Cont.of(a);
    });
  }

  /// Promotes an error to success, ignoring the error value.
  ///
  /// Similar to [promote] but the promotion function takes no arguments.
  ///
  /// - [f]: Zero-argument function that returns a success value.
  Cont<E, F, A> promote0(A Function() f) {
    return promote((_) {
      return f();
    });
  }

  /// Promotes an error to success with access to both error and environment.
  ///
  /// Similar to [promote], but the promotion function receives both the
  /// error and the environment. This is useful when promotion logic
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and error, and returns a success value.
  Cont<E, F, A> promoteWithEnv(
    A Function(E env, F error) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return promote((error) {
        return f(e, error);
      });
    });
  }

  /// Promotes an error to success with access to the environment only.
  ///
  /// Similar to [promoteWithEnv], but the promotion function only receives
  /// the environment and ignores the error.
  ///
  /// - [f]: Function that takes the environment and returns a success value.
  Cont<E, F, A> promoteWithEnv0(A Function(E env) f) {
    return promoteWithEnv((e, _) {
      return f(e);
    });
  }

  /// Promotes an error to success with a constant fallback value.
  ///
  /// If the continuation terminates with an error, succeeds with [value] instead.
  /// This is the simplest form of promotion.
  ///
  /// - [value]: The value to use when the continuation terminates with an error.
  Cont<E, F, A> promoteWith(A value) {
    return promote0(() {
      return value;
    });
  }
}
