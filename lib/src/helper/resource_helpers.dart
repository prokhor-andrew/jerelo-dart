part of '../cont.dart';

/// Implementation of the bracket (acquire / use / release) pattern.
///
/// Acquires a resource via [acquire], passes it to [use], and guarantees
/// that [release] runs afterwards regardless of whether [use] succeeds,
/// terminates, or is cancelled. The release phase runs on a
/// non-cancellable runtime to ensure cleanup always completes.
///
/// Error handling:
/// - If both [use] and [release] succeed, returns the value from [use].
/// - If [use] succeeds but [release] terminates, propagates release error.
/// - If [use] terminates but [release] succeeds, propagates use error.
/// - If both terminate, merges errors using [combine].
Cont<E, F, A> _bracket<E, F, R, A>({
  required Cont<E, F, R> acquire,
  required Cont<E, F, ()> Function(R resource) release,
  required Cont<E, F, A> Function(R resource) use,
  required ContError<F> Function(ContError<F> useError, ContError<F> releaseError) combine,
}) {
  if (acquire is Cont<E, F, Never>) {
    acquire = acquire.absurd<R>();
  }

  return acquire.thenDo((resource) {
    return Cont.fromRun((runtime, observer) {
      // Create a non-cancellable runtime for the release phase so that
      // cleanup always completes even if the parent is cancelled.
      final releaseRuntime = ContRuntime<E>._(
        runtime.env(),
        () => false,
        runtime.onPanic,
      );

      // Runs release and merges the outcome with [useResult].
      void doRelease(_Either<A, ContError<F>> useResult) {
        Cont<E, F, ()> releaseCont;
        try {
          final cont = release(resource);
          releaseCont =
              (cont is Cont<E, F, Never>) ? cont.absurd<()>() : cont;
        } catch (error, st) {
          releaseCont = Cont.stop<E, F, ()>(
            ThrownError.withStackTrace(error, st),
          );
        }

        releaseCont._run(
          releaseRuntime,
          ContObserver._(
            // Release terminated
            (releaseError) {
              switch (useResult) {
                case _Left<A, ContError<F>>():
                  // Use succeeded but release failed
                  observer.onElse(releaseError);
                case _Right<A, ContError<F>>(value: final useError):
                  // Both failed – merge errors
                  try {
                    observer.onElse(combine(useError, releaseError));
                  } catch (error, st) {
                    observer.onElse(
                      ThrownError.withStackTrace(error, st),
                    );
                  }
              }
            },
            // Release succeeded
            (_) {
              switch (useResult) {
                case _Left<A, ContError<F>>(value: final value):
                  // Both succeeded – return the use value
                  observer.onThen(value);
                case _Right<A, ContError<F>>(value: final useError):
                  // Use failed but release succeeded – propagate use error
                  observer.onElse(useError);
              }
            },
          ),
        );
      }

      // If already cancelled before the use phase, still release the
      // resource but do not emit anything to the observer.
      if (runtime.isCancelled()) {
        try {
          Cont<E, F, ()> releaseCont = release(resource);
          if (releaseCont is Cont<E, F, Never>) {
            releaseCont = releaseCont.absurd<()>();
          }
          releaseCont._run(
            releaseRuntime,
            ContObserver._(_ignore, _ignore),
          );
        } catch (_) {
          // Ignore exceptions during release when already cancelled.
        }
        return;
      }

      // Execute the use phase
      try {
        Cont<E, F, A> useCont = use(resource);
        if (useCont is Cont<E, F, Never>) {
          useCont = useCont.absurd<A>();
        }

        useCont._run(
          runtime,
          ContObserver._(
            (useError) => doRelease(_Right(useError)),
            (value) => doRelease(_Left(value)),
          ),
        );
      } catch (error, st) {
        doRelease(_Right(ThrownError.withStackTrace(error, st)));
      }
    });
  });
}
