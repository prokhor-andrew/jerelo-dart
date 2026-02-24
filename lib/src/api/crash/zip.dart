part of '../../cont.dart';

/// Implementation of fallback with crash accumulation on the crash path.
///
/// Runs [cont], and on crash executes the fallback produced by [f].
/// If the fallback also crashes, crashes from both attempts are merged
/// into a [MergedCrash] before being propagated.
Cont<E, F, A> _crashZip<E, F, A>(
  Cont<E, F, A> cont,
  Cont<E, F, A> Function(ContCrash crash) f,
) {
  return cont.crashDo((crash1) {
    return ContCrash.tryCatch(() {
      return f(crash1).absurdify().crashDo((crash2) {
        return Cont.crash(MergedCrash._(crash1, crash2));
      });
    }).match((cont) => cont, (crash2) {
      return Cont.crash(
        MergedCrash._(crash1, crash2),
      );
    });
  });
}

extension ContCrashZipExtension<E, F, A> on Cont<E, F, A> {
  /// Attempts a fallback continuation and combines crashes from both attempts.
  ///
  /// If the continuation crashes, executes the fallback. If the fallback also
  /// crashes, combines crashes from both attempts before propagating.
  ///
  /// Unlike [crashDo], which only keeps the second crash, this method
  /// accumulates and combines crashes from both attempts.
  ///
  /// - [f]: Function that receives original crash and produces a fallback continuation.
  Cont<E, F, A> crashZip(
    Cont<E, F, A> Function(ContCrash crash) f,
  ) {
    return _crashZip(this, f);
  }

  /// Zero-argument version of [crashZip].
  ///
  /// Similar to [crashZip] but doesn't use the original crash information
  /// when producing the fallback continuation.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<E, F, A> crashZip0(
    Cont<E, F, A> Function() f,
  ) {
    return crashZip((_) {
      return f();
    });
  }

  /// Attempts a fallback continuation with access to the environment and combines crashes.
  ///
  /// Similar to [crashZip], but the fallback function receives both the original
  /// crash and the environment. If both the original attempt and fallback crash,
  /// their crashes are combined. This is useful when crash recovery strategies
  /// need access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and crash, and produces a fallback continuation.
  Cont<E, F, A> crashZipWithEnv(
    Cont<E, F, A> Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashZip((crash) {
        return f(e, crash);
      });
    });
  }

  /// Attempts a fallback continuation with access to the environment only and combines crashes.
  ///
  /// Similar to [crashZipWithEnv], but the fallback function only receives the
  /// environment and ignores the original crash information.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  Cont<E, F, A> crashZipWithEnv0(
    Cont<E, F, A> Function(E env) f,
  ) {
    return crashZipWithEnv((e, _) {
      return f(e);
    });
  }
}
