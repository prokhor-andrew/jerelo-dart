part of '../../cont.dart';

extension ContRecoverExtension<E, A> on Cont<E, A> {
  /// Recovers from termination by computing a replacement value from the errors.
  ///
  /// If the continuation terminates, applies [f] to the error list and succeeds
  /// with the returned value. This is a convenience over [elseDo] for cases
  /// where the recovery logic is a pure function rather than a full continuation.
  ///
  /// - [f]: Function that receives the termination errors and returns a recovery value.
  Cont<E, A> recover(A Function(List<ContError> errors) f) {
    return elseDo((errors) {
      final a = f(errors);
      return Cont.of(a);
    });
  }

  /// Recovers from termination by computing a replacement value, ignoring the errors.
  ///
  /// Similar to [recover] but the recovery function takes no arguments.
  ///
  /// - [f]: Zero-argument function that returns a recovery value.
  Cont<E, A> recover0(A Function() f) {
    return recover((_) {
      return f();
    });
  }

  Cont<E, A> recoverWithEnv(
    A Function(E env, List<ContError> errors) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return recover((errors) {
        return f(e, errors);
      });
    });
  }

  Cont<E, A> recoverWithEnv0(A Function(E env) f) {
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
  Cont<E, A> recoverWith(A value) {
    return recover0(() {
      return value;
    });
  }
}
