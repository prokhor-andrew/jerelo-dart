part of '../cont.dart';

/// Creates a [Cont] from a raw run function with safety guarantees.
///
/// Wraps the user-supplied [run] function with:
/// - Cancellation checks before execution and in each callback.
/// - Idempotence guards ensuring callbacks fire at most once.
/// - Exception catching around [run] itself (converts thrown errors to
///   termination).
/// - Panic handling when observer callbacks throw.
/// - Special handling for [ContObserver]<[Never]> observers.
Cont<E, F, A> _fromRun<E, F, A>(
  void Function(
    ContRuntime<E> runtime,
    ContObserver<F, A> observer,
  ) run,
) {
  return Cont._((runtime, observer) {
    if (runtime.isCancelled()) {
      return;
    }

    if (observer is ContObserver<F, Never>) {
      observer =
          ContObserver<F, A>._(observer.onElse, (_) {});
    }

    bool isDone = false;

    void guardedTerminate(List<ContError<F>> errors) {
      errors = errors.toList(); // defensive copy
      if (runtime.isCancelled()) {
        return;
      }

      if (isDone) {
        return;
      }
      isDone = true;
      try {
        observer.onElse(errors);
      } catch (error, st) {
        try {
          runtime.onPanic(
            ThrownError(error, st),
          );
        } catch (error, st) {
          _panic(ThrownError(error, st));
        }
      }
    }

    void guardedValue(A a) {
      if (runtime.isCancelled()) {
        return;
      }

      if (isDone) {
        return;
      }
      isDone = true;
      try {
        observer.onThen(a);
      } catch (error, st) {
        try {
          runtime.onPanic(
            ThrownError(error, st),
          );
        } catch (error, st) {
          _panic(
            ThrownError(error, st),
          );
        }
      }
    }

    try {
      run(
        runtime,
        ContObserver._(guardedTerminate, guardedValue),
      );
    } catch (error, st) {
      guardedTerminate([
        ThrownError<F>(error, st),
      ]);
    }
  });
}
