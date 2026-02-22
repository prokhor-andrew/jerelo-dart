import 'package:jerelo/jerelo.dart';

extension ContCrashRecoverExtension<E, F, A>
    on Cont<E, F, A> {
  /// Recovers from a crash by computing a replacement value from the crash.
  ///
  /// If the continuation crashes, applies [f] to the crash and succeeds
  /// with the returned value. This is a convenience over [crashDo] for cases
  /// where the recovery logic is a pure function rather than a full continuation.
  ///
  /// - [f]: Function that receives the crash and returns a recovery value.
  Cont<E, F, A> crashRecoverThen(
    A Function(ContCrash crash) f,
  ) {
    return crashDo((crash) {
      final a = f(crash);
      return Cont.of(a);
    });
  }

  /// Recovers from a crash by computing a replacement value, ignoring the crash.
  ///
  /// Similar to [crashRecoverThen] but the recovery function takes no arguments.
  ///
  /// - [f]: Zero-argument function that returns a recovery value.
  Cont<E, F, A> crashRecoverThen0(A Function() f) {
    return crashRecoverThen((_) {
      return f();
    });
  }

  /// Recovers from a crash with access to both crash and environment.
  ///
  /// Similar to [crashRecoverThen], but the recovery function receives both the
  /// crash and the environment. This is useful when recovery logic
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and crash, and returns a recovery value.
  Cont<E, F, A> crashRecoverThenWithEnv(
    A Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashRecoverThen((crash) {
        return f(e, crash);
      });
    });
  }

  /// Recovers from a crash with access to the environment only.
  ///
  /// Similar to [crashRecoverThenWithEnv], but the recovery function only receives
  /// the environment and ignores the crash.
  ///
  /// - [f]: Function that takes the environment and returns a recovery value.
  Cont<E, F, A> crashRecoverThenWithEnv0(A Function(E env) f) {
    return crashRecoverThenWithEnv((e, _) {
      return f(e);
    });
  }

  /// Recovers from a crash with a constant fallback value.
  ///
  /// If the continuation crashes, succeeds with [value] instead.
  /// This is the simplest form of crash recovery to a success value.
  ///
  /// - [value]: The value to use when the continuation crashes.
  Cont<E, F, A> crashRecoverThenWith(A value) {
    return crashRecoverThen0(() {
      return value;
    });
  }

  /// Recovers from a crash by computing an error from the crash.
  ///
  /// If the continuation crashes, applies [f] to the crash and terminates
  /// with the returned error. This is a convenience over [crashDo] for cases
  /// where the recovery logic produces an error rather than a success value.
  ///
  /// - [f]: Function that receives the crash and returns an error.
  Cont<E, F, A> crashRecoverElse(
    F Function(ContCrash crash) f,
  ) {
    return crashDo((crash) {
      final error = f(crash);
      return Cont.error(error);
    });
  }

  /// Recovers from a crash by computing an error, ignoring the crash.
  ///
  /// Similar to [crashRecoverElse] but the recovery function takes no arguments.
  ///
  /// - [f]: Zero-argument function that returns an error.
  Cont<E, F, A> crashRecoverElse0(F Function() f) {
    return crashRecoverElse((_) {
      return f();
    });
  }

  /// Recovers from a crash with access to both crash and environment.
  ///
  /// Similar to [crashRecoverElse], but the recovery function receives both the
  /// crash and the environment. This is useful when recovery logic
  /// needs access to configuration or context information.
  ///
  /// - [f]: Function that takes the environment and crash, and returns an error.
  Cont<E, F, A> crashRecoverElseWithEnv(
    F Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashRecoverElse((crash) {
        return f(e, crash);
      });
    });
  }

  /// Recovers from a crash with access to the environment only.
  ///
  /// Similar to [crashRecoverElseWithEnv], but the recovery function only receives
  /// the environment and ignores the crash.
  ///
  /// - [f]: Function that takes the environment and returns an error.
  Cont<E, F, A> crashRecoverElseWithEnv0(F Function(E env) f) {
    return crashRecoverElseWithEnv((e, _) {
      return f(e);
    });
  }

  /// Recovers from a crash with a constant fallback error.
  ///
  /// If the continuation crashes, terminates with [error] instead.
  /// This is the simplest form of crash recovery to an error.
  ///
  /// - [error]: The error to use when the continuation crashes.
  Cont<E, F, A> crashRecoverElseWith(F error) {
    return crashRecoverElse0(() {
      return error;
    });
  }
}
