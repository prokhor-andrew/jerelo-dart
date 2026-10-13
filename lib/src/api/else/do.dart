part of '../../cont.dart';

extension ContElseDoExtension<E, F, A> on Cont<E, F, A> {
  /// Provides a fallback continuation in case of termination.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback
  /// also terminates, only the fallback's error is propagated (the original
  /// error is discarded).
  ///
  /// To accumulate errors from both attempts, use [elseZip] instead.
  ///
  /// - [f]: Function that receives error and produces a fallback continuation.
  Cont<E, F2, A> elseDo<F2>(
    Cont<E, F2, A> Function(F error) f,
  ) {
    return Cont.fromRun((env, observer) {
      final cancellers = _Cancellers();
      cancellers.runNext(() {
        return runWith(
          env,
          observer.copyUpdateOnElse((error) {
            final result = ContCrash.tryCatch(() {
              final contA = f(error);
              cancellers.runNext(() {
                return contA.runWith(env, observer);
              });
            });
            if (result
                case CrashCrashOr(crash: final crash)) {
              observer.onCrash(crash);
            }
          }),
        );
      });
      return cancellers.cancel;
    });
  }
}
