part of '../cont.dart';

/// Implementation of monadic bind (flatMap) on the termination path.
///
/// Runs [cont], and on termination passes the errors to [f] to produce a
/// fallback continuation. If the fallback also terminates, only its errors
/// are propagated (the original errors are discarded).
Cont<E, F, A> _elseDo<E, F, A>(
  Cont<E, F, A> cont,
  Cont<E, F, A> Function(List<ContError<F>> errors) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        errors = errors.toList(); // defensive copy
        try {
          Cont<E, F, A> contA = f(errors);

          if (contA is Cont<E, F, Never>) {
            contA = contA.absurd<A>();
          }

          contA._run(
            runtime,
            observer.copyUpdateOnElse((errors2) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onElse([...errors2]);
            }),
          );
        } catch (error, st) {
          observer.onElse([
            ThrownError(error, st),
          ]); // we return latest error
        }
      }),
    );
  });
}

/// Implementation of side-effect execution on the termination path.
///
/// Runs [cont], and on termination executes the side-effect continuation
/// produced by [f]. If the side-effect terminates, the original errors are
/// propagated. If the side-effect succeeds, recovery occurs with the
/// side-effect's value.
Cont<E, F, A> _elseTap<E, F, A>(
  Cont<E, F, A> cont,
  Cont<E, F, A> Function(List<ContError<F>> errors) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        errors = errors.toList(); // defensive copy
        try {
          // another defensive copy
          // we need it in case somebody mutates errors inside "f"
          // and then crashes it. In that case we'd go to catch block below,
          // and "errors" there would be different now, which should not happen
          Cont<E, F, A> contA = f(errors.toList());

          if (contA is Cont<E, F, Never>) {
            contA = contA.absurd<A>();
          }

          contA._run(
            runtime,
            observer.copyUpdateOnElse((_) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onElse(errors);
            }),
          );
        } catch (_) {
          // we return original errors
          observer.onElse(errors);
        }
      }),
    );
  });
}

/// Implementation of fallback with error accumulation on the termination path.
///
/// Runs [cont], and on termination executes the fallback produced by [f].
/// If the fallback also terminates, errors from both attempts are
/// concatenated before being propagated.
Cont<E, F, A> _elseZip<E, F, A>(
  Cont<E, F, A> cont,
  Cont<E, F, A> Function(List<ContError<F>>) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        errors = errors.toList(); // defensive copy
        try {
          // another defensive copy
          // we need it in case somebody mutates errors inside "f"
          // and then crashes it. In that case we'd go to catch block below,
          // and "errors" there would be different now, which should not happen
          Cont<E, F, A> contA = f(errors.toList());
          if (contA is Cont<E, F, Never>) {
            contA = contA.absurd<A>();
          }
          contA._run(
            runtime,
            observer.copyUpdateOnElse((errors2) {
              if (runtime.isCancelled()) {
                return;
              }
              errors2 = errors2.toList(); // defensive copy
              final combinedErrors = errors + errors2;
              observer.onElse(combinedErrors);
            }),
          );
        } catch (error, st) {
          final combinedErrors =
              errors + [ThrownError(error, st)];
          observer.onElse(combinedErrors);
        }
      }),
    );
  });
}

/// Implementation of the fire-and-forget fork on the termination path.
///
/// Runs [cont], and on termination starts the side-effect continuation
/// produced by [f] without waiting for it. The original termination errors
/// are forwarded to the observer immediately. Errors from the side-effect
/// are silently ignored.
Cont<E, F, A> _elseFork<E, F, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F, A2> Function(List<ContError<F>> errors) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnElse((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        // if this crashes, it should crash the computation
        Cont<E, F, A2> contA2 = f([...errors]);
        if (contA2 is Cont<E, F, Never>) {
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
        observer.onElse([...errors]);
      }),
    );
  });
}
