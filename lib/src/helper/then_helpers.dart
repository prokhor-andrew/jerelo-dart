part of '../cont.dart';

Cont<E, A> _thenFork<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(A a) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnValue((a) {
        if (runtime.isCancelled()) {
          return;
        }

        // if this crashes, it should crash the computation
        Cont<E, A2> contA2 = f(a);

        if (contA2 is Cont<E, Never>) {
          contA2 = contA2.absurd<A2>();
        }

        try {
          contA2.ff(
            runtime.env(),
            onPanic: runtime.onPanic,
          );
        } catch (_) {
          // do nothing, if anything happens to side-effect, it's not
          // a concern of the thenFork
        }

        observer.onValue(a);
      }),
    );
  });
}

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
