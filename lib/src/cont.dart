import 'package:jerelo/jerelo.dart';

part 'api/cont_crash.dart';
part 'api/cont_runtime.dart';
part 'api/cont_observer.dart';
part 'api/cont_cancel_token.dart';
part 'api/then/fork.dart';
part 'api/else/fork.dart';
part 'api/then/while.dart';
part 'api/else/while.dart';
part 'helper/utils.dart';

/// A continuation monad representing a computation that will eventually
/// produce a value of type [A] or terminate with error.
///
/// [Cont] provides a powerful abstraction for managing asynchronous operations,
/// error handling, and composition of effectful computations. It follows the
/// continuation-passing style where computations are represented as functions
/// that take callbacks for success and failure.
///
/// Type parameters:
/// - [E]: The environment type providing context for the continuation execution.
/// - [A]: The value type that the continuation produces upon success.
final class Cont<E, F, A> {
  final void Function(
    ContRuntime<E> runtime,
    ContObserver<F, A> observer,
  ) _run;

  const Cont._(this._run);

  ContCancelToken run(
    E env, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F error) onElse = _ignore,
    void Function(A value) onThen = _ignore,
  }) {
    final cancelToken = ContCancelToken._();

    runWith(
      ContRuntime._(env, cancelToken.isCancelled),
      ContObserver._(onPanic, onCrash, onElse, onThen),
    );

    return cancelToken;
  }

  void runWith(
    ContRuntime<E> runtime,
    ContObserver<F, A> observer,
  ) {
    _run(
      runtime,
      observer,
    );
  }

  /// Creates a [Cont] from a run function that accepts an observer.
  ///
  /// Constructs a continuation with guaranteed idempotence and exception catching.
  /// The run function receives an observer with `onThen` and `onElse` callbacks.
  /// The callbacks should be called as the last instruction in the run function
  /// or saved to be called later.
  ///
  /// - [run]: Function that executes the continuation and calls observer callbacks.
  static Cont<E, F, A> fromRun<E, F, A>(
    void Function(
      ContRuntime<E> runtime,
      ContObserver<F, A> observer,
    ) run,
  ) {
    return Cont._((runtime, observer) {
      if (runtime.isCancelled()) {
        return;
      }

      void onPanic(NormalCrash crash) {
        try {
          observer._onUnsafePanic(crash);
        } catch (error, st) {
          // the important part here is that if onPanic crashes,
          // we don't push the crash that was sent there,
          // but the crash that caused the onPanic
          _panic(NormalCrash._(error, st));
        }
      }

      observer = observer.absurdify();

      bool isDone = false;

      void guardedOnCrash(ContCrash crash) {
        if (runtime.isCancelled()) {
          return;
        }

        if (isDone) {
          return;
        }

        isDone = true;

        try {
          observer._onCrash(crash);
        } catch (error, st) {
          onPanic(NormalCrash._(error, st));
        }
      }

      void guardedOnError(F error) {
        if (runtime.isCancelled()) {
          return;
        }

        if (isDone) {
          return;
        }

        isDone = true;
        try {
          observer.onElse(error);
        } catch (error, st) {
          onPanic(NormalCrash._(error, st));
        }
      }

      void guardedOnValue(A a) {
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
          onPanic(NormalCrash._(error, st));
        }
      }

      try {
        run(
          runtime,
          ContObserver._(
            onPanic,
            guardedOnCrash,
            guardedOnError,
            guardedOnValue,
          ),
        );
      } catch (error, st) {
        observer._onCrash(NormalCrash._(error, st));
      }
    });
  }

  /// Creates a [Cont] from a deferred continuation computation.
  ///
  /// Lazily evaluates a continuation-returning function. The inner [Cont] is
  /// not created until the outer one is executed.
  ///
  /// - [thunk]: Function that returns a [Cont] when called.
  static Cont<E, F, A> fromDeferred<E, F, A>(
    Cont<E, F, A> Function() thunk,
  ) {
    return Cont.fromRun((runtime, observer) {
      Cont<E, F, A> contA = thunk().absurdify();
      contA._run(runtime, observer);
    });
  }

  /// Creates a [Cont] that immediately succeeds with a value.
  ///
  /// Identity operation that wraps a pure value in a continuation context.
  ///
  /// - [value]: The value to wrap.
  static Cont<E, F, A> of<E, F, A>(A value) {
    return Cont.fromRun((runtime, observer) {
      observer.onThen(value);
    });
  }

  /// Creates a [Cont] that immediately terminates with optional error.
  ///
  /// Creates a continuation that terminates without producing a value.
  /// Used to represent failure states.
  ///
  /// - [error]: List of error to terminate with. Defaults to an empty list.
  static Cont<E, F, A> error<E, F, A>(F err) {
    return Cont.fromRun((runtime, observer) {
      observer.onElse(err);
    });
  }

  /// Retrieves the current environment value.
  ///
  /// Accesses the environment of type [E] from the runtime context.
  /// This is used to read configuration, dependencies, or any contextual
  /// information that flows through the continuation execution.
  ///
  /// Returns a continuation that succeeds with the environment value.
  static Cont<E, F, E> askThen<E, F>() {
    return Cont.fromRun((runtime, observer) {
      observer.onThen(runtime.env());
    });
  }

  static Cont<E, E, A> askElse<E, A>() {
    return Cont.fromRun((runtime, observer) {
      observer.onElse(runtime.env());
    });
  }

  /// Runs two continuations and combines their results according to the specified policy.
  ///
  /// Executes both continuations. Both must succeed for the result to be successful;
  /// if either fails, the entire operation fails. When both succeed, their values
  /// are combined using [combine].
  ///
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [BothSequencePolicy]: Runs [left] then [right] sequentially.
  /// - [BothMergeWhenAllPolicy]: Runs both in parallel, waits for both to complete,
  ///   and merges error if both fail.
  /// - [BothQuitFastPolicy]: Runs both in parallel, terminates immediately if either fails.
  ///
  /// - [left]: First continuation to execute.
  /// - [right]: Second continuation to execute.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and error are handled.
  static Cont<E, F, A3> both<E, F, A1, A2, A3>(
    Cont<E, F, A1> left,
    Cont<E, F, A2> right,
    A3 Function(A1 a, A2 a2) combine, {
    required ContPolicy<F> policy,
  }) {
    left = left.absurdify();
    right = right.absurdify();

    switch (policy) {
      case SequencePolicy():
        return left.thenDo((a) {
          return right.thenMap((a2) {
            return combine(a, a2);
          });
        });
      case MergeWhenAllPolicy(combine: final combine2):
        return _bothWhenAll(left, right, combine, combine2);
      case QuitFastPolicy():
        return _bothQuitFast(left, right, combine);
    }
  }

  /// Runs multiple continuations and collects all results according to the specified policy.
  ///
  /// Executes all continuations in [list] and collects their values into a list.
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [BothSequencePolicy]: Runs continuations one by one in order, stops at first failure.
  /// - [BothMergeWhenAllPolicy]: Runs all in parallel, waits for all to complete,
  ///   and merges error if any fail.
  /// - [BothQuitFastPolicy]: Runs all in parallel, terminates immediately on first failure.
  ///
  /// - [list]: List of continuations to execute.
  /// - [policy]: Execution policy determining how continuations are run and error are handled.
  static Cont<E, F, List<A>> all<E, F, A>(
    List<Cont<E, F, A>> list, {
    required ContPolicy<F> policy,
  }) {
    switch (policy) {
      case SequencePolicy():
        return _allSequence(list);
      case MergeWhenAllPolicy(combine: final combine):
        return _whenAllAll(list, combine);
      case QuitFastPolicy():
        return _quitFastAll(list);
    }
  }

  /// Races two continuations, returning the first successful value.
  ///
  /// Executes both continuations and returns the result from whichever succeeds first.
  /// If both fail, concatenates their error. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [SequencePolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [MergeWhenAllPolicy]: Runs both in parallel, returns first success or merges
  ///   results using the policy's combine function if both succeed.
  /// - [QuitFastPolicy]: Runs both in parallel, returns immediately on first success.
  ///
  /// - [left]: First continuation to try.
  /// - [right]: Second continuation to try.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, F3, A> either<E, F1, F2, F3, A>(
    Cont<E, F1, A> left,
    Cont<E, F2, A> right,
    F3 Function(F1, F2) combine, {
    required ContPolicy<A> policy,
  }) {
    left = left.absurdify();
    right = right.absurdify();

    switch (policy) {
      case SequencePolicy<A>():
        return left.elseDo((error1) {
          return right.elseMap((error2) {
            return combine(error1, error2);
          });
        });
      case MergeWhenAllPolicy<A>(combine: final combine2):
        return _eitherWhenAll(
          left,
          right,
          combine,
          combine2,
        );
      case QuitFastPolicy<A>():
        return _eitherQuitFast(left, right, combine);
    }
  }

  /// Races multiple continuations, returning the first successful value.
  ///
  /// Executes all continuations in [list] and returns the first one that succeeds.
  /// If all fail, collects all error. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [SequencePolicy]: Tries continuations one by one in order until one succeeds.
  /// - [MergeWhenAllPolicy]: Runs all in parallel, returns first success or merges
  ///   results using the policy's combine function if multiple succeed.
  /// - [QuitFastPolicy]: Runs all in parallel, returns immediately on first success.
  ///
  /// - [list]: List of continuations to race.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, List<F>, A> any<E, F, A>(
    List<Cont<E, F, A>> list, {
    required ContPolicy<A> policy,
    //
  }) {
    switch (policy) {
      case SequencePolicy<A>():
        return _anySequence(list);
      case MergeWhenAllPolicy<A>(combine: final combine):
        return _whenAllAny(list, combine);
      case QuitFastPolicy<A>():
        return _quitFastAny(list);
    }
  }

  static Cont<E, F, A> bracket<R, E, F, A>({
    required Cont<E, Never, R> acquire,
    required Cont<E, Never, ()> Function(
      R resource,
    ) release,
    required Cont<E, F, A> Function(R resource) use,
    //
  }) {
    return Cont.fromRun((runtime, observer) {
    });
  }
}
