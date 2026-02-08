part of '../cont.dart';

Cont<E, A> _bracket<E, R, A>({
  required Cont<E, R> acquire,
  required Cont<E, ()> Function(R resource) release,
  required Cont<E, A> Function(R resource) use,
  //
}) {
  if (acquire is Cont<E, Never>) {
    acquire = acquire.absurd<R>();
  }

  return acquire.thenDo((resource) {
    return Cont.fromRun((runtime, observer) {
      // Create a non-cancellable runtime for the release phase
      // This ensures release always runs, even if the parent is cancelled
      final releaseRuntime = ContRuntime<E>._(
        runtime.env(),
        () {
          return false;
        },
        runtime.onPanic,
      );

      // Helper to safely call release and handle its result
      // Uses _Either to distinguish between success (value) and failure (errors)
      void doRelease(
        _Either<A, List<ContError>> useResult,
      ) {
        // Create helper to get release continuation safely
        Cont<E, ()> getReleaseCont() {
          try {
            final cont = release(resource);
            if (cont is Cont<E, Never>) {
              return cont.absurd<()>();
            }
            return cont;
          } catch (error, st) {
            return Cont.terminate<E, ()>([
              ContError(error, st),
            ]);
          }
        }

        // Run release with non-cancellable runtime
        try {
          final releaseCont = getReleaseCont();
          releaseCont._run(
            releaseRuntime, // Use non-cancellable runtime
            ContObserver._(
              // Release terminated - combine with use errors if any
              (releaseErrors) {
                switch (useResult) {
                  case _Left<A, List<ContError>>():
                    // Use succeeded but release failed
                    observer.onTerminate([
                      ...releaseErrors,
                    ]);
                  case _Right<A, List<ContError>>(
                    value: final useErrors,
                  ):
                    // Both use and release failed - combine errors
                    final combinedErrors = [
                      ...useErrors,
                      ...releaseErrors,
                    ];
                    observer.onTerminate(combinedErrors);
                }
              },
              // Release succeeded
              (_) {
                switch (useResult) {
                  case _Left<A, List<ContError>>(
                    value: final value,
                  ):
                    // Both use and release succeeded - return the value
                    observer.onValue(value);
                  case _Right<A, List<ContError>>(
                    value: final useErrors,
                  ):
                    // Use failed but release succeeded - propagate use errors
                    observer.onTerminate(useErrors);
                }
              },
            ),
          );
        } catch (error, st) {
          // Exception while setting up release
          switch (useResult) {
            case _Left<A, List<ContError>>():
              // Use succeeded but release setup failed
              observer.onTerminate([ContError(error, st)]);
            case _Right<A, List<ContError>>(
              value: final useErrors,
            ):
              // Both use and release setup failed
              final combinedErrors = [
                ...useErrors,
                ContError(error, st),
              ];
              observer.onTerminate(combinedErrors);
          }
        }
      }

      // Check cancellation before starting use phase
      if (runtime.isCancelled()) {
        // Still attempt to release the resource even if cancelled
        doRelease(_Right(const []));
        return;
      }

      // Execute the use phase
      try {
        Cont<E, A> useCont = use(resource);
        if (useCont is Cont<E, Never>) {
          useCont = useCont.absurd<A>();
        }

        useCont._run(
          runtime,
          ContObserver._(
            // Use phase terminated
            (useErrors) {
              // Always release, even on termination
              doRelease(_Right([...useErrors]));
            },
            // Use phase succeeded
            (value) {
              // Always release after successful use
              doRelease(_Left(value));
            },
          ),
        );
      } catch (error, st) {
        // Exception while setting up use phase - still release
        doRelease(_Right([ContError(error, st)]));
      }
    });
  });
}
