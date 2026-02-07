part of '../cont.dart';

/// Creates a [Cont] from a run function with idempotence and exception catching.
///
/// Internal implementation for [Cont.fromRun].
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
      observer = ContObserver<A>._(
        observer.onTerminate,
        (_) {},
      );
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
      observer.onTerminate(errors);
    }

    void guardedValue(A a) {
      if (runtime.isCancelled()) {
        return;
      }

      if (isDone) {
        return;
      }
      isDone = true;
      observer.onValue(a);
    }

    try {
      run(
        runtime,
        ContObserver._(guardedTerminate, guardedValue),
      );
    } catch (error, st) {
      guardedTerminate([ContError(error, st)]);
    }
  });
}
