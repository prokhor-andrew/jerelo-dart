import 'package:jerelo/jerelo.dart';

extension ContCrashDoExtension<E, F, A> on Cont<E, F, A> {
  /// Provides a recovery continuation in case of a crash.
  ///
  /// If the continuation crashes, executes the recovery continuation returned
  /// by [f]. If the recovery also crashes, only the recovery's crash is
  /// propagated (the original crash is discarded).
  ///
  /// To accumulate crashes from both attempts, use `crashZip` from the
  /// jerelo_ext package instead.
  ///
  /// - [f]: Function that receives the crash and produces a recovery continuation.
  Cont<E, F, A> crashDo(
    Cont<E, F, A> Function(ContCrash crash) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      runWith(
        runtime,
        observer.copyUpdateOnCrash((initialCrash) {
          final result = ContCrash.tryCatch(() {
            final cont = f(initialCrash);
            cont.runWith(runtime, observer);
          });
          if (result
              case CrashCrashOr(crash: final crash)) {
            observer.onCrash(crash);
          }
        }),
      );
    });
  }
}
