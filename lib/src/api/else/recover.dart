import 'package:jerelo/jerelo.dart';

extension ContRecoverExtension<E, F, A> on Cont<E, F, A> {
  /// Recovers from termination by computing a replacement value from the error.
  ///
  /// If the continuation terminates, applies [f] to the error list and succeeds
  /// with the returned value. This is a convenience over [elseDo] for cases
  /// where the recovery logic is a pure function rather than a full continuation.
  ///
  /// - [f]: Function that receives the termination error and returns a recovery value.
  Cont<E, F, A> recover(A Function(F error) f) {
    return elseDo((error) {
      final a = f(error);
      return Cont.of(a);
    });
  }

  /// Recovers from termination by computing a replacement value, ignoring the error.
  ///
  /// Similar to [recover] but the recovery function takes no arguments.
  ///
  /// - [f]: Zero-argument function that returns a recovery value.
  Cont<E, F, A> recover0(A Function() f) {
    return recover((_) {
      return f();
    });
  }

  /// Recovers from termination with access to both error and environment.
  ///
  /// Similar to [recover], but the recovery function receives both the
  /// termination error and the environment. This is useful when recovery logic
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and error, and returns a recovery value.
  Cont<E, F, A> recoverWithEnv(
    A Function(E env, F error) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return recover((error) {
        return f(e, error);
      });
    });
  }

  /// Recovers from termination with access to the environment only.
  ///
  /// Similar to [recoverWithEnv], but the recovery function only receives
  /// the environment and ignores the termination error.
  ///
  /// - [f]: Function that takes the environment and returns a recovery value.
  Cont<E, F, A> recoverWithEnv0(A Function(E env) f) {
    return recoverWithEnv((e, _) {
      return f(e);
    });
  }

  /// Recovers from termination with a constant fallback value.
  ///
  /// If the continuation terminates, succeeds with [value] instead.
  /// This is the simplest form of error recovery.
  ///
  /// - [value]: The value to use when the continuation terminates.
  Cont<E, F, A> recoverWith(A value) {
    return recover0(() {
      return value;
    });
  }
}
