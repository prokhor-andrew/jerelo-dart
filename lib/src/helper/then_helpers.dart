part of '../cont.dart';

/// Implementation of the fire-and-forget fork on the success path.
///
/// Runs [cont], and on success starts the side-effect continuation produced
/// by [f] without waiting for it. The original value is forwarded to the
/// observer immediately. Error from the side-effect are silently ignored.
Cont<E, F, A> _thenFork<E, F, F2, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F2, A2> Function(A a) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnThen((a) {
        if (runtime.isCancelled()) {
          return;
        }

        // if this crashes, it should crash the computation
        Cont<E, F2, A2> contA2 = f(a);

        if (contA2 is Cont<E, F2, Never>) {
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

        observer.onThen(a);
      }),
    );
  });
}

/// Implementation of monadic bind (flatMap) on the success path.
///
/// Runs [cont], and on success passes the value to [f] to produce the next
/// continuation, which is then run with the same runtime and observer.
/// If [f] throws, the error is caught and forwarded as a termination.
Cont<E, F, A2> _thenDo<E, F, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F, A2> Function(A value) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnThen((a) {
        if (runtime.isCancelled()) {
          return;
        }
        try {
          Cont<E, F, A2> contA2 = f(a);
          if (contA2 is Cont<E, F, Never>) {
            contA2 = contA2.absurd<A2>();
          }
          contA2._run(runtime, observer);
        } catch (error, st) {
          observer.onElse(
            ThrownError.withStackTrace(error, st),
          );
        }
      }),
    );
  });
}
