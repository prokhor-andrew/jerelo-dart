import 'package:jerelo/jerelo.dart';

part 'api/cont_crash.dart';
part 'api/cont_runtime.dart';
part 'api/cont_observer.dart';
part 'api/cont_cancel_token.dart';
part 'api/then/fork.dart';
part 'api/else/fork.dart';
part 'api/then/while.dart';
part 'api/else/while.dart';
part 'api/crash/fork.dart';
part 'api/crash/while.dart';
part 'api/crash/zip.dart';
part 'helper/utils.dart';

part 'helper/sequence_helpers.dart';
part 'helper/quit_fast_helpers.dart';
part 'helper/quit_fast_list_helpers.dart';
part 'helper/when_all_helpers.dart';
part 'helper/when_all_list_helpers.dart';

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
      _UnsafeObserver._(onPanic, onCrash, onElse, onThen),
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
      SafeObserver<F, A> observer,
    ) run,
  ) {
    return Cont._((runtime, observer) {
      if (runtime.isCancelled()) {
        return;
      }

      observer = observer.absurdify();

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

      bool isDone = false;

      void guardedOnCrash(ContCrash crash) {
        if (runtime.isCancelled()) {
          isDone = true;
          return;
        }

        if (isDone) {
          return;
        }

        isDone = true;

        try {
          observer.onCrash(crash);
        } catch (error, st) {
          onPanic(NormalCrash._(error, st));
        }
      }

      void guardedOnElse(F error) {
        if (runtime.isCancelled()) {
          isDone = true;
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

      void guardedOnThen(A a) {
        if (runtime.isCancelled()) {
          isDone = true;
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
          SafeObserver._(
            () {
              return isDone;
            },
            onPanic,
            guardedOnCrash,
            guardedOnElse,
            guardedOnThen,
          ),
        );
      } catch (error, st) {
        guardedOnCrash(NormalCrash._(error, st));
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
      contA.runWith(runtime, observer);
    });
  }

  static Cont<E, F, A> crash<E, F, A>(ContCrash crash) {
    return Cont.fromRun((runtime, observer) {
      observer.onCrash(crash);
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
    required OkPolicy<F> policy,
  }) {
    left = left.absurdify();
    right = right.absurdify();

    switch (policy) {
      case SequenceOkPolicy():
        return left.thenDo((a) {
          return right.thenMap((a2) {
            return combine(a, a2);
          });
        });
      case QuitFastOkPolicy():
        return _bothQuitFast(left, right, combine);
      case RunAllOkPolicy(
          combine: final combineErrors,
          shouldFavorCrash: final shouldFavorCrash,
        ):
        return _bothWhenAll(
          left,
          right,
          combine,
          combineErrors,
          shouldFavorCrash,
        );
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
    required OkPolicy<F> policy,
  }) {
    switch (policy) {
      case SequenceOkPolicy():
        return _allSequence(list);
      case QuitFastOkPolicy():
        return _quitFastAll(list);
      case RunAllOkPolicy(combine: final combine):
        return _whenAllAll(list, combine);
    }
  }

  /// Races two continuations, returning the first successful value.
  ///
  /// Executes both continuations and returns the result from whichever succeeds first.
  /// If both fail, concatenates their error. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [RunAllOkPolicy]: Runs both in parallel, returns first success or merges
  ///   results using the policy's combine function if both succeed.
  /// - [QuitFastOkPolicy]: Runs both in parallel, returns immediately on first success.
  ///
  /// - [left]: First continuation to try.
  /// - [right]: Second continuation to try.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, F3, A> either<E, F1, F2, F3, A>(
    Cont<E, F1, A> left,
    Cont<E, F2, A> right,
    F3 Function(F1, F2) combine, {
    required OkPolicy<A> policy,
  }) {
    left = left.absurdify();
    right = right.absurdify();

    switch (policy) {
      case SequenceOkPolicy<A>():
        return left.elseDo((error1) {
          return right.elseMap((error2) {
            return combine(error1, error2);
          });
        });
      case QuitFastOkPolicy<A>():
        return _eitherQuitFast(left, right, combine);
      case RunAllOkPolicy<A>(
          combine: final combineValues,
          shouldFavorCrash: final shouldFavorCrash,
        ):
        return _eitherWhenAll(
          left,
          right,
          combine,
          combineValues,
          shouldFavorCrash,
        );
    }
  }

  /// Races multiple continuations, returning the first successful value.
  ///
  /// Executes all continuations in [list] and returns the first one that succeeds.
  /// If all fail, collects all error. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Tries continuations one by one in order until one succeeds.
  /// - [RunAllOkPolicy]: Runs all in parallel, returns first success or merges
  ///   results using the policy's combine function if multiple succeed.
  /// - [QuitFastOkPolicy]: Runs all in parallel, returns immediately on first success.
  ///
  /// - [list]: List of continuations to race.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, List<F>, A> any<E, F, A>(
    List<Cont<E, F, A>> list, {
    required OkPolicy<A> policy,
  }) {
    switch (policy) {
      case SequenceOkPolicy<A>():
        return _anySequence(list);
      case QuitFastOkPolicy<A>():
        return _quitFastAny(list);
      case RunAllOkPolicy<A>(combine: final combine):
        return _whenAllAny(list, combine);
    }
  }

  static Cont<E, F, A> xxx<E, F, A>(
    Cont<E, F, A> left,
    Cont<E, F, A> right, {
    required CrashPolicy<F, A> policy,
  }) {
    left = left.absurdify();
    right = right.absurdify();

    switch (policy) {
      case SequenceCrashPolicy():
        return left.crashDo((crash1) {
          return right.crashDo((crash2) {
            return Cont.crash(
              MergedCrash._(crash1, crash2),
            );
          });
        });
      case QuitFastCrashPolicy():
        return _crashQuitFast(left, right);
      case RunAllCrashPolicy():
        // TODO:
        throw "";
    }
  }

  /// Acquires a resource, uses it, and guarantees its release.
  ///
  /// Implements the bracket pattern for safe resource management. Regardless
  /// of whether [use] succeeds, fails, or crashes, [release] is always called
  /// with the acquired resource.
  ///
  /// - [acquire]: Obtains the resource. Cannot produce a business-logic error
  ///   (error type is [Never]); it can only succeed or crash.
  /// - [release]: Releases the resource. Cannot produce a business-logic error
  ///   (error type is [Never]); it can only succeed or crash.
  /// - [use]: Uses the resource; may succeed with [A], fail with [F], or crash.
  ///
  /// Outcome rules after [release] completes:
  /// - [use] succeeded  → propagate the success value (unless [release] crashes).
  /// - [use] failed     → propagate the failure error (unless [release] crashes).
  /// - [use] crashed    → propagate the crash; if [release] also crashes, the
  ///   two crashes are merged into a [MergedCrash].
  /// - [release] crashes in any case → that crash is forwarded to [onCrash].
  static Cont<E, F, A> bracket<R, E, F, A>({
    required Cont<E, Never, R> acquire,
    required Cont<E, Never, ()> Function(
      R resource,
    ) release,
    required Cont<E, F, A> Function(R resource) use,
  }) {
    return Cont.fromRun((runtime, observer) {
      acquire.elseAbsurd<F>().runWith(
        runtime,
        observer.copyUpdateOnThen<R>((r) {
          if (runtime.isCancelled()) {
            return;
          }

          void withRelease({
            required void Function() onReleaseOk,
            required void Function(ContCrash releaseCrash)
                onReleaseCrash,
          }) {
            final crash = ContCrash.tryCatch(() {
              release(r).elseAbsurd<F>().runWith(
                    runtime,
                    observer.copyUpdateOnThen<()>((_) {
                      if (runtime.isCancelled()) return;
                      onReleaseOk();
                    }).copyUpdateOnCrash(onReleaseCrash),
                  );
            });
            if (crash != null) {
              onReleaseCrash(crash);
            }
          }

          final crash = ContCrash.tryCatch(() {
            use(r).absurdify().runWith(
                  runtime,
                  observer.copyUpdateOnThen<A>((a) {
                    if (runtime.isCancelled()) return;
                    withRelease(
                      onReleaseOk: () => observer.onThen(a),
                      onReleaseCrash: (rc) =>
                          observer.onCrash(rc),
                    );
                  }).copyUpdateOnElse<F>((error) {
                    if (runtime.isCancelled()) return;
                    withRelease(
                      onReleaseOk: () =>
                          observer.onElse(error),
                      onReleaseCrash: (rc) =>
                          observer.onCrash(rc),
                    );
                  }).copyUpdateOnCrash((useCrash) {
                    withRelease(
                      onReleaseOk: () =>
                          observer.onCrash(useCrash),
                      onReleaseCrash: (rc) =>
                          observer.onCrash(
                              MergedCrash._(useCrash, rc)),
                    );
                  }),
                );
          });

          if (crash != null) {
            observer.onCrash(crash);
          }
        }),
      );
    });
  }
}
