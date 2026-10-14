part of '../cont.dart';

/// Implementation of the fire-and-forget fork on the success path.
///
/// Runs [cont], and on success starts the side-effect continuation produced
/// by [f] without waiting for it. The original value is forwarded to the
/// observer once the side-effect has been started, so a synchronous
/// side-effect runs to completion first. The side-effect's outcome is
/// ignored; if [f] itself throws, the computation terminates with that error.
Cont<E, A> _thenFork<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(A a) f,
) {
  // built on thenDo, so a chain of forks stays stack safe
  return cont.thenDo((a) {
    return Cont.fromRun((runtime, observer) {
      // if building the side-effect throws, terminate the computation
      final contA2 = f(a);
      try {
        contA2.ff(runtime.env(), onPanic: runtime.onPanic);
      } catch (_) {
        // do nothing, if anything happens to side-effect, it's not
        // a concern of the thenFork
      }
      observer.onThen(a);
    });
  });
}

/// Implementation of monadic bind (flatMap) on the success path.
///
/// Runs [cont], and on success passes the value to [f] to produce the next
/// continuation, which is then run with the same runtime and observer.
/// If [f] throws, the error is caught and forwarded as a termination.
Cont<E, A2> _thenDo<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(A value) f,
) {
  return _ThenDoCont<E, A, A2>(cont, f);
}
