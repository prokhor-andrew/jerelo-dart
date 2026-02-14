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
Cont<E, A> _fromRun<E, A>(
  void Function(
    ContRuntime<E> runtime,
    ContObserver<A> observer,
  )
  run,
) {
  return Cont._((runtime, observer) {
    if (runtime.isCancelled()) {
      return;
    }

    if (observer is ContObserver<Never>) {
      observer = ContObserver<A>._(observer.onElse, (_) {});
    }

    bool isDone = false;

    void guardedTerminate(List<ContError> errors) {
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
            ContError.withStackTrace(error, st),
          );
        } catch (error, st) {
          _panic(ContError.withStackTrace(error, st));
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
            ContError.withStackTrace(error, st),
          );
        } catch (error, st) {
          _panic(ContError.withStackTrace(error, st));
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
        ContError.withStackTrace(error, st),
      ]);
    }
  });
}
