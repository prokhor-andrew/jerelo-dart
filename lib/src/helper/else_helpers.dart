part of '../cont.dart';

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
              errors2 = errors2.toList(); // defensive copy
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

Cont<E, A> _elseFork<E, A, A2>(
  Cont<E, A> cont,
  Cont<E, A2> Function(List<ContError> errors) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont._run(
      runtime,
      observer.copyUpdateOnTerminate((errors) {
        if (runtime.isCancelled()) {
          return;
        }
        // if this crashes, it should crash the computation
        Cont<E, A2> contA2 = f([...errors]);
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
          // a concern of the orElseFork
        }
        observer.onTerminate([...errors]);
      }),
    );
  });
}
