part of '../cont.dart';

/// Implementation of monadic bind (flatMap) on the termination path.
///
/// Runs [cont], and on termination passes the errors to [f] to produce a
/// fallback continuation. If the fallback also terminates, only its errors
/// are propagated (the original errors are discarded).
Cont<E, A> _elseDo<E, A>(
  Cont<E, A> cont,
  Cont<E, A> Function(List<ContError> errors) f,
) {
  return _ElseDoCont<E, A>(cont, f);
}

/// Implementation of side-effect execution on the termination path.
///
/// Runs [cont], and on termination executes the side-effect continuation
/// produced by [f]. If the side-effect terminates, the original errors are
/// propagated. If the side-effect succeeds, recovery occurs with the
/// side-effect's value.
Cont<E, A> _elseTap<E, A>(
  Cont<E, A> cont,
  Cont<E, A> Function(List<ContError> errors) f,
) {
  // built on elseDo, so a chain of taps stays stack safe
  return cont.elseDo((errors) {
    final Cont<E, A> contA;
    try {
      // another defensive copy, in case f mutates the errors and then
      // throws: the original errors are returned unchanged
      contA = f(errors.toList());
    } catch (_) {
      // we return original errors
      return Cont.stop(errors);
    }
    // a value recovers; errors are replaced by the original ones
    return contA.elseDo((_) {
      return Cont.stop(errors);
    });
  });
}

/// Implementation of fallback with error accumulation on the termination path.
///
/// Runs [cont], and on termination executes the fallback produced by [f].
/// If the fallback also terminates, errors from both attempts are
/// concatenated before being propagated.
Cont<E, A> _elseZip<E, A>(
  Cont<E, A> cont,
  Cont<E, A> Function(List<ContError>) f,
) {
  // built on elseDo, so a chain of zips stays stack safe
  return cont.elseDo((errors) {
    final Cont<E, A> contA;
    try {
      // another defensive copy, in case f mutates the errors and then
      // throws: the original errors are combined unchanged
      contA = f(errors.toList());
    } catch (error, st) {
      return Cont.stop(
        errors + [ContError.withStackTrace(error, st)],
      );
    }
    // a value recovers; errors are added to the original ones
    return contA.elseDo((errors2) {
      return Cont.stop(errors + errors2);
    });
  });
}

/// Implementation of the fire-and-forget fork on the termination path.
///
/// Runs [cont], and on termination starts the side-effect continuation
/// produced by [f] without waiting for it. The original termination errors
/// are forwarded to the observer once the side-effect has been started, so a
/// synchronous side-effect runs to completion first. The side-effect's
/// outcome is ignored; if [f] itself throws, the computation terminates with
/// that error.
Cont<E, A> _elseFork<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(List<ContError> errors) f,
) {
  // built on elseDo, so a chain of forks stays stack safe
  return cont.elseDo((errors) {
    return Cont.fromRun((runtime, observer) {
      // if building the side-effect throws, terminate the computation
      final contA2 = f([...errors]);
      try {
        contA2.ff(runtime.env(), onPanic: runtime.onPanic);
      } catch (_) {
        // do nothing, if anything happens to side-effect, it's not
        // a concern of the orElseFork
      }
      observer.onElse([...errors]);
    });
  });
}
