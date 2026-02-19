part of '../cont.dart';

/// Implementation of monadic bind (flatMap) on the termination path.
///
/// Runs [cont], and on termination passes the error to [f] to produce a
/// fallback continuation. If the fallback also terminates, only its error
/// are propagated (the original error are discarded).
Cont<E, F2, A> _elseDo<E, F, F2, A>(
  Cont<E, F, A> cont,
  Cont<E, F2, A> Function(ContError<F> error) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((error) {
        if (runtime.isCancelled()) {
          return;
        }

        try {
          Cont<E, F2, A> contA = f(error);

          if (contA is Cont<E, F2, Never>) {
            contA = contA.absurd<A>();
          }

          contA._run(
            runtime,
            observer.copyUpdateOnElse((error2) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onElse(error2);
            }),
          );
        } catch (error, st) {
          observer.onElse(
            ThrownError.withStackTrace(error, st),
          ); // we return latest error
        }
      }),
    );
  });
}

/// Implementation of side-effect execution on the termination path.
///
/// Runs [cont], and on termination executes the side-effect continuation
/// produced by [f]. If the side-effect terminates, the original error are
/// propagated. If the side-effect succeeds, recovery occurs with the
/// side-effect's value.
Cont<E, F, A> _elseTap<E, F, F2, A>(
  Cont<E, F, A> cont,
  Cont<E, F2, A> Function(ContError<F> error) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((error) {
        if (runtime.isCancelled()) {
          return;
        }
        try {
          Cont<E, F2, A> contA = f(error);

          if (contA is Cont<E, F2, Never>) {
            contA = contA.absurd<A>();
          }

          contA._run(
            runtime,
            observer.copyUpdateOnElse((_) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onElse(error);
            }),
          );
        } catch (_) {
          // we return original error
          observer.onElse(error);
        }
      }),
    );
  });
}

/// Implementation of fallback with error accumulation on the termination path.
///
/// Runs [cont], and on termination executes the fallback produced by [f].
/// If the fallback also terminates, error from both attempts are
/// concatenated before being propagated.
Cont<E, F3, A> _elseZip<E, F, F2, F3, A>(
  Cont<E, F, A> cont,
  Cont<E, F2, A> Function(ContError<F>) f,
  ContError<F3> Function(ContError<F> f1, ContError<F2> f2)
      combine,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((error) {
        if (runtime.isCancelled()) {
          return;
        }
        try {
          Cont<E, F2, A> contA = f(error);
          if (contA is Cont<E, F2, Never>) {
            contA = contA.absurd<A>();
          }
          contA._run(
            runtime,
            observer.copyUpdateOnElse((error2) {
              if (runtime.isCancelled()) {
                return;
              }

              try {
                final combinedError =
                    combine(error, error2);
                observer.onElse(combinedError);
              } catch (thrownError, st) {
                observer.onElse(
                  ThrownError.withStackTrace(
                    thrownError,
                    st,
                  ),
                );
              }
            }),
          );
        } catch (thrownError, st) {
          try {
            final combinedError = combine(
              error,
              ThrownError.withStackTrace(thrownError, st),
            );
            observer.onElse(combinedError);
          } catch (thrownError2, st) {
            observer.onElse(
              ThrownError.withStackTrace(thrownError2, st),
            );
          }
        }
      }),
    );
  });
}

/// Implementation of the fire-and-forget fork on the termination path.
///
/// Runs [cont], and on termination starts the side-effect continuation
/// produced by [f] without waiting for it. The original termination error
/// are forwarded to the observer immediately. error from the side-effect
/// are silently ignored.
Cont<E, F, A> _elseFork<E, F, F2, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F2, A2> Function(ContError<F> error) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((error) {
        if (runtime.isCancelled()) {
          return;
        }
        // if this crashes, it should crash the computation
        Cont<E, F2, A2> contA2 = f(error);
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
          // a concern of the orElseFork
        }
        observer.onElse(error);
      }),
    );
  });
}
