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
    return Cont.fromRun((runtime, observer) {
      runWith(
        runtime,
        observer.copyUpdateOnThen((a) {
          ContCrash.tryCatch(() {
            final contA2 = f(a);
            contA2.runWith(runtime, observer);
          }).match((_) {}, observer.onCrash);
        }),
      );
    });
  }
}
