import 'package:jerelo/jerelo.dart';

extension ContThenDoExtension<E, F, A> on Cont<E, F, A> {
  /// Chains a [Cont]-returning function to create dependent computations.
  ///
  /// Monadic bind operation. Sequences continuations where the second depends
  /// on the result of the first.
  ///
  /// - [f]: Function that takes a value and returns a continuation.
  Cont<E, F, A2> thenDo<A2>(
    Cont<E, F, A2> Function(A value) f,
  ) {
    return Cont.fromRun((env, observer) {
      runWith(
        env,
        observer.copyUpdateOnThen((a) {
          final result = ContCrash.tryCatch(() {
            final contA2 = f(a);
            contA2.runWith(env, observer);
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
