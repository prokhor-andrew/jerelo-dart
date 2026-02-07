part of '../cont.dart';

/// Chains a [Cont]-returning function to create dependent computations.
///
/// Internal implementation for [Cont.thenDo].
Cont<E, A2> _thenDo<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(A value) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnValue((a) {
        if (runtime.isCancelled()) {
          return;
        }
        try {
          Cont<E, A2> contA2 = f(a);
          if (contA2 is Cont<E, Never>) {
            contA2 = contA2.absurd<A2>();
          }
          contA2._run(runtime, observer);
        } catch (error, st) {
          observer.onTerminate([ContError(error, st)]);
        }
      }),
    );
  });
}
