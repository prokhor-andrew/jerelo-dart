part of '../cont.dart';

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
      try {
        observer.onTerminate(errors);
      } catch (error, st) {
        try {
          runtime.onPanic(ContError(error, st));
        } catch (error, st) {
          _panic(ContError(error, st));
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
        observer.onValue(a);
      } catch (error, st) {
        try {
          runtime.onPanic(ContError(error, st));
        } catch (error, st) {
          _panic(ContError(error, st));
        }
      }
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
