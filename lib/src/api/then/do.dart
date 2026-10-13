part of '../../cont.dart';

extension ContThenDoExtension<E, F, A> on Cont<E, F, A> {
  /// Chains a [Cont]-returning function to create dependent computations.
  ///
  /// Monadic bind operation. Sequences continuations where the second depends
  /// on the result of the first. Errors and crashes of this continuation are
  /// passed through, and a throw from [f] becomes a crash. A cancel is
  /// forwarded to whichever of the two continuations is running.
  ///
  /// - [f]: Function that takes a value and returns a continuation.
  Cont<E, F, A2> thenDo<A2>(
    Cont<E, F, A2> Function(A value) f,
  ) {
    return Cont.fromRun((env, observer) {
      final cancellers = _Cancellers();
      cancellers.runNext(() {
        return runWith(
          env,
          observer.copyUpdateOnThen((a) {
            final result = ContCrash.tryCatch(() {
              final contA2 = f(a);
              cancellers.runNext(() {
                return contA2.runWith(env, observer);
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
