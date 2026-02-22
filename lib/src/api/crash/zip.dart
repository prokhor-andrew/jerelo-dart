import 'package:jerelo/jerelo.dart';

/// Implementation of fallback with crash accumulation on the crash path.
///
/// Runs [cont], and on crash executes the fallback produced by [f].
/// If the fallback also crashes, crashes from both attempts are
/// combined before being propagated.
///
Cont<E, F, A> _crashZip<E, F, A>(
  Cont<E, F, A> cont,
  Cont<E, F, A> Function(ContCrash crash) f,
  ContCrash Function(ContCrash c1, ContCrash c2) combine,
) {
  return Cont.fromRun((runtime, observer) {
    cont.runWith(
      runtime,
      observer.copyUpdateOnCrash((crash) {
        if (runtime.isCancelled()) {
          return;
        }

        final outerCrash = ContCrash.tryCatch(() {
          final Cont<E, F, A> contA = f(crash).absurdify();

          contA.runWith(
            runtime,
            observer.copyUpdateOnCrash((crash2) {
              if (runtime.isCancelled()) {
                return;
              }

              final innerCrash = ContCrash.tryCatch(() {
                final combinedCrash = combine(
                  crash,
                  crash2,
                );
                observer.onCrash(combinedCrash);
              });

              if (innerCrash != null) {
                observer.onCrash(innerCrash);
              }
            }),
          );
        });

        if (outerCrash != null) {
          observer.onCrash(outerCrash);
        }
      }),
    );
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
  /// - [combine]: Function to combine the two crashes.
  Cont<E, F, A> crashZip(
    Cont<E, F, A> Function(ContCrash crash) f,
    ContCrash Function(ContCrash c1, ContCrash c2) combine,
  ) {
    return _crashZip(this, f, combine);
  }

  /// Zero-argument version of [crashZip].
  ///
  /// Similar to [crashZip] but doesn't use the original crash information
  /// when producing the fallback continuation.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  /// - [combine]: Function to combine the two crashes.
  Cont<E, F, A> crashZip0(
    Cont<E, F, A> Function() f,
    ContCrash Function(ContCrash c1, ContCrash c2) combine,
  ) {
    return crashZip((_) {
      return f();
    }, combine);
  }

  /// Attempts a fallback continuation with access to the environment and combines crashes.
  ///
  /// Similar to [crashZip], but the fallback function receives both the original
  /// crash and the environment. If both the original attempt and fallback crash,
  /// their crashes are combined. This is useful when crash recovery strategies
  /// need access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and crash, and produces a fallback continuation.
  /// - [combine]: Function to combine the two crashes.
  Cont<E, F, A> crashZipWithEnv(
    Cont<E, F, A> Function(E env, ContCrash crash) f,
    ContCrash Function(ContCrash c1, ContCrash c2) combine,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashZip((crash) {
        return f(e, crash);
      }, combine);
    });
  }

  /// Attempts a fallback continuation with access to the environment only and combines crashes.
  ///
  /// Similar to [crashZipWithEnv], but the fallback function only receives the
  /// environment and ignores the original crash information.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  /// - [combine]: Function to combine the two crashes.
  Cont<E, F, A> crashZipWithEnv0(
    Cont<E, F, A> Function(E env) f,
    ContCrash Function(ContCrash c1, ContCrash c2) combine,
  ) {
    return crashZipWithEnv((e, _) {
      return f(e);
    }, combine);
  }
}
