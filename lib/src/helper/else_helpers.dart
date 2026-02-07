part of '../cont.dart';

/// Provides a fallback continuation in case of termination.
///
/// Internal implementation for [Cont.elseDo].
Cont<E, A> _elseDo<E, A>(
  Cont<E, A> cont,
  Cont<E, A> Function(List<ContError> errors) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnTerminate((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        errors = errors.toList(); // defensive copy
        try {
          Cont<E, A> contA = f(errors);

          if (contA is Cont<E, Never>) {
            contA = contA.absurd<A>();
          }

          contA._run(
            runtime,
            observer.copyUpdateOnTerminate((errors2) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onTerminate([...errors2]);
            }),
          );
        } catch (error, st) {
          observer.onTerminate([
            ContError(error, st),
          ]); // we return latest error
        }
      }),
    );
  });
}

/// Executes a side-effect continuation on termination.
///
/// Internal implementation for [Cont.elseTap].
Cont<E, A> _elseTap<E, A>(
  Cont<E, A> cont,
  Cont<E, A> Function(List<ContError> errors) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnTerminate((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        errors = errors.toList(); // defensive copy
        try {
          // another defensive copy
          // we need it in case somebody mutates errors inside "f"
          // and then crashes it. In that case we'd go to catch block below,
          // and "errors" there would be different now, which should not happen
          Cont<E, A> contA = f(errors.toList());

          if (contA is Cont<E, Never>) {
            contA = contA.absurd<A>();
          }

          contA._run(
            runtime,
            observer.copyUpdateOnTerminate((_) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onTerminate(errors);
            }),
          );
        } catch (_) {
          // we return original errors
          observer.onTerminate(errors);
        }
      }),
    );
  });
}

/// Attempts a fallback continuation and combines errors from both attempts.
///
/// Internal implementation for [Cont.elseZip].
Cont<E, A> _elseZip<E, A>(
  Cont<E, A> cont,
  Cont<E, A> Function(List<ContError>) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnTerminate((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        errors = errors.toList(); // defensive copy
        try {
          // another defensive copy
          // we need it in case somebody mutates errors inside "f"
          // and then crashes it. In that case we'd go to catch block below,
          // and "errors" there would be different now, which should not happen
          Cont<E, A> contA = f(errors.toList());
          if (contA is Cont<E, Never>) {
            contA = contA.absurd<A>();
          }
          contA._run(
            runtime,
            observer.copyUpdateOnTerminate((errors2) {
              if (runtime.isCancelled()) {
                return;
              }
              errors2 = errors2
                  .toList(); // defensive copy
              final combinedErrors = errors + errors2;
              observer.onTerminate(combinedErrors);
            }),
          );
        } catch (error, st) {
          final combinedErrors =
              errors + [ContError(error, st)];
          observer.onTerminate(combinedErrors);
        }
      }),
    );
  });
}

/// Executes a side-effect continuation on termination in a fire-and-forget manner.
///
/// Internal implementation for [Cont.elseFork].
Cont<E, A> _elseFork<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(List<ContError> errors) f,
) {
  return cont.elseDoWithEnv((e, errors) {
    // this should not be inside try-catch block
    Cont<E, A2> contA2 = f([...errors]);
    if (contA2 is Cont<E, Never>) {
      contA2 = contA2.absurd<A2>();
    }
    try {
      contA2.ff(e);
    } catch (_) {
      // do nothing, if anything happens to side-effect, it's not
      // a concern of the orElseFork
    }
    return Cont.terminate<E, A>([...errors]);
  });
}
