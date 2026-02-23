import 'package:jerelo/jerelo.dart';

extension ContCrashDoExtension<E, F, A> on Cont<E, F, A> {
  /// Provides a recovery continuation in case of a crash.
  ///
  /// If the continuation crashes, executes the recovery continuation returned
  /// by [f]. If the recovery also crashes, only the recovery's crash is
  /// propagated (the original crash is discarded).
  ///
  /// To accumulate crashes from both attempts, use [crashZip] instead.
  ///
  /// - [f]: Function that receives the crash and produces a recovery continuation.
  Cont<E, F, A> crashDo(
    Cont<E, F, A> Function(ContCrash crash) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      runWith(
        runtime,
        observer.copyUpdateOnCrash((initialCrash) {
          if (runtime.isCancelled()) {
            return;
          }

          final resultCrash = ContCrash.tryCatch(() {
            final cont = f(initialCrash).absurdify();
            cont.runWith(runtime, observer);
          });

          if (resultCrash != null) {
            observer.onCrash(resultCrash);
          }
        }),
      );
    });
  }

  /// Provides a zero-argument recovery continuation in case of a crash.
  ///
  /// Similar to [crashDo] but the recovery function doesn't use the crash
  /// information.
  ///
  /// - [f]: Zero-argument function that produces a recovery continuation.
  Cont<E, F, A> crashDo0(Cont<E, F, A> Function() f) {
    return crashDo((_) {
      return f();
    });
  }

  /// Provides a recovery continuation with access to both crash and environment.
  ///
  /// Similar to [crashDo], but the recovery function receives both the crash
  /// and the environment. This is useful when crash recovery needs access to
  /// configuration or context from the environment.
  ///
  /// - [f]: Function that takes the environment and crash, and returns a recovery continuation.
  Cont<E, F, A> crashDoWithEnv(
    Cont<E, F, A> Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashDo((crash) {
        return f(e, crash);
      });
    });
  }

  /// Provides a recovery continuation with access to the environment only.
  ///
  /// Similar to [crashDoWithEnv], but the recovery function only receives the
  /// environment and ignores the crash information.
  ///
  /// - [f]: Function that takes the environment and returns a recovery continuation.
  Cont<E, F, A> crashDoWithEnv0(
    Cont<E, F, A> Function(E env) f,
  ) {
    return crashDoWithEnv((e, _) {
      return f(e);
    });
  }
}
