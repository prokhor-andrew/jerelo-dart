import 'package:jerelo/jerelo.dart';

part 'api/cont_crash.dart';
part 'api/cont_observer.dart';
part 'api/tail_rec.dart';
part 'api/cont_cancel_token.dart';
part 'api/then/do.dart';
part 'api/else/do.dart';
part 'api/crash/do.dart';
part 'api/then/while.dart';
part 'api/else/while.dart';
part 'api/crash/while.dart';
part 'api/env/env.dart';
part 'helper/utils.dart';
part 'helper/run_loop.dart';

part 'helper/sequence_helpers.dart';
part 'helper/quit_fast_helpers.dart';
part 'helper/quit_fast_list_helpers.dart';
part 'helper/when_all_helpers.dart';
part 'helper/when_all_list_helpers.dart';

/// A continuation monad representing a computation that will eventually
/// produce a value, terminate with a business-logic error, or crash.
///
/// [Cont] provides a powerful abstraction for managing asynchronous operations,
/// error handling, and composition of effectful computations. It follows the
/// continuation-passing style where computations are represented as functions
/// that take callbacks for each of the three outcome channels.
///
/// Type parameters:
/// - [E]: The environment type providing context for the continuation execution.
/// - [F]: The error type that the continuation may terminate with on the else channel.
/// - [A]: The value type that the continuation produces upon success.
//
// A Cont is data: a leaf (_LeafCont, built by fromRun) that runs a
// function, or a node that composes other Conts (_ThenDoCont,
// _ElseDoCont, _CrashDoCont). runWith interprets the nodes with a
// loop and an explicit frame stack (see run_loop.dart), so chains of
// any length don't grow the call stack.
sealed class Cont<E, F, A> {
  const Cont._();

  /// Executes the continuation with the given environment.
  ///
  /// Runs the continuation and routes its outcome to the appropriate callback.
  ///
  /// - [env]: The environment value to provide to the computation.
  /// - [onPanic]: Called when [onCrash], [onElse] or [onThen] throws, with
  ///   the thrown error as a [NormalCrash]. Defaults to rethrowing the panic
  ///   in a microtask, so it surfaces as an unhandled error in the current
  ///   zone; a `try`/`catch` around [run] never sees it. If [onPanic]
  ///   itself throws, the original panic is rethrown that way instead.
  /// - [onCrash]: Called when the computation terminates on the crash channel.
  ///   Defaults to silently ignoring the crash.
  /// - [onElse]: Called when the computation terminates on the else (error) channel.
  ///   Defaults to silently ignoring the error.
  /// - [onThen]: Called when the computation succeeds with a value.
  ///   Defaults to silently ignoring the value.
  ///
  /// Returns a [ContCancelToken] that cancels the computation.
  ContCancelToken run(
    E env, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F error) onElse = _ignore,
    void Function(A value) onThen = _ignore,
  }) {
    return ContCancelToken._(
      runWith(
        env,
        _UnsafeObserver._(onPanic, onCrash, onElse, onThen),
      ),
    );
  }

  /// Creates a [Cont] from a run function that accepts an observer.
  ///
  /// Constructs a continuation that reports at most one outcome and catches
  /// exceptions. The run function receives the environment and an observer
  /// with `onCrash`, `onElse` and `onThen` callbacks.
  /// The callbacks should be called as the last instruction in the run function
  /// or saved to be called later. A callback called while [run] is still
  /// running only records the outcome: the next stage starts after [run]
  /// returns, so code after the call runs first. A callback called later
  /// runs the next stages before it returns.
  ///
  /// Only the observer handed to [run] is guarded against duplicate calls;
  /// observers derived from it with `copyUpdate*` call their new callbacks
  /// every time.
  ///
  /// Only exceptions thrown synchronously by [run] are caught. One thrown
  /// before the observer was called is a crash; one thrown after it is a
  /// panic, and the reported outcome stands. An exception thrown later, for
  /// example inside a `Timer` or `Future` callback, escapes to the zone and
  /// the observer is not called; wrap such callbacks in [ContCrash.tryCatch]
  /// and pass the crash to `observer.onCrash`.
  ///
  /// [run] returns the canceller of the work it started. It is called when
  /// the computation is cancelled, at most once, and never after the
  /// observer was called. The canceller decides what cancelling means, for
  /// example stopping a timer, and reports the outcome through the
  /// observer. Return a no-op (`() {}`) when the work can't be cancelled; the
  /// computation then just finishes. A throw from the canceller is a crash,
  /// or a panic if the observer was already called.
  ///
  /// - [run]: Function that executes the continuation, calls observer
  ///   callbacks, and returns a canceller.
  static Cont<E, F, A> fromRun<E, F, A>(
    void Function() Function(
      E env,
      SafeObserver<F, A> observer,
    ) run,
  ) {
    return _LeafCont<E, F, A>._((
      env,
      onUnsafePanic,
      onCrash,
      onElse,
      onThen,
    ) {
      void onPanic(NormalCrash crash) {
        ContCrash.tryCatch(() {
          onUnsafePanic(crash);
        })._ifCrash((_) {
          // if onPanic throws, rethrow the panic it was handling,
          // not its own error: the original panic is the real problem
          _panic(crash);
        });
      }

      bool isDone = false;

      void guardedOnCrash(ContCrash crash) {
        if (isDone) {
          return;
        }

        isDone = true;

        ContCrash.tryCatch(() {
          onCrash(crash);
        })._ifCrash(onPanic);
      }

      void guardedOnElse(F error) {
        if (isDone) {
          return;
        }

        isDone = true;

        ContCrash.tryCatch(() {
          onElse(error);
        })._ifCrash(onPanic);
      }

      void guardedOnThen(A a) {
        if (isDone) {
          return;
        }

        isDone = true;

        ContCrash.tryCatch(() {
          onThen(a);
        })._ifCrash(onPanic);
      }

      // a throw before the leaf reports is a crash; after it, the
      // outcome stands and the throw is a panic
      void crashOrPanic(NormalCrash crash) {
        if (isDone) {
          onPanic(crash);
        } else {
          guardedOnCrash(crash);
        }
      }

      void Function() canceller = _voidIgnore;

      ContCrash.tryCatch(() {
        canceller = run(
          env,
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
      })._ifCrash(crashOrPanic);

      // the leaf's canceller runs at most once, and not after the leaf
      // has finished
      bool isCancelled = false;
      return () {
        if (isCancelled || isDone) {
          return;
        }
        isCancelled = true;
        ContCrash.tryCatch(canceller)
            ._ifCrash(crashOrPanic);
      };
    });
  }

  /// Creates a [Cont] that immediately terminates on the crash channel.
  ///
  /// - [crash]: The [ContCrash] value to propagate.
  static Cont<E, F, A> crash<E, F, A>(ContCrash crash) {
    return Cont.fromRun((env, observer) {
      observer.onCrash(crash);
      return _voidIgnore;
    });
  }

  /// Creates a [Cont] whose continuation is built only when it runs.
  ///
  /// [thunk] is called on every run, so each run gets a freshly built
  /// continuation. Use it to delay expensive construction, or to create
  /// per-run state.
  ///
  /// A throw from [thunk] becomes a crash. A cancel is forwarded to the
  /// continuation it built.
  ///
  /// - [thunk]: Builds the continuation to run.
  static Cont<E, F, A> fromDeferred<E, F, A>(
    Cont<E, F, A> Function() thunk,
  ) {
    return _DeferCont<E, F, A>(thunk);
  }

  /// Creates a [Cont] that immediately succeeds with a value.
  ///
  /// Identity operation that wraps a pure value in a continuation context.
  ///
  /// - [value]: The value to wrap.
  static Cont<E, F, A> of<E, F, A>(A value) {
    return Cont.fromRun((env, observer) {
      observer.onThen(value);
      return _voidIgnore;
    });
  }

  // Runs step repeatedly, starting from initial, until it succeeds with
  // _DoneTailRec; _NextTailRec runs the next iteration with the new
  // state, and an else or crash outcome ends the loop. A throw from step
  // is a crash. Iterations that complete synchronously don't grow the
  // call stack. A cancel is forwarded to the running iteration, and to
  // every iteration that starts afterwards. step receives isCancelled:
  // the loop operators (thenWhile, elseWhile, crashWhile) are built on
  // it, and once it returns true they end with the iteration's outcome
  // instead of starting another one.
  static Cont<E, F, A> _tailRecM<E, F, S, A>(
    S initial,
    Cont<E, F, _TailRec<S, A>> Function(
      S state,
      bool Function() isCancelled,
    ) step,
  ) {
    return Cont.fromRun((env, observer) {
      final cancellers = _Cancellers();
      _stackSafeLoop<
          _Triple<S, ContCrash, _Either<F, A>>, // state
          S, // loop input
          _Either<ContCrash, _Either<F, A>> // loop output
          >(
        seed: _Value1(initial),
        keepRunningIf: (state) {
          switch (state) {
            case _Value1(a: final state):
              return _StackSafeLoopPolicyKeepRunning(state);
            case _Value2(b: final crash):
              return _StackSafeLoopPolicyStop(_Left(crash));
            case _Value3(c: final outcome):
              return _StackSafeLoopPolicyStop(
                  _Right(outcome));
          }
        },
        computation: (state, update) {
          ContCrash.tryCatch(() {
            final contStep = step(
              state,
              () => cancellers.isCancelled,
            );
            cancellers.runNext(() {
              return contStep.runWith(
                env,
                observer.copyUpdate<F, _TailRec<S, A>>(
                  onCrash: (crash) {
                    update(_Value2(crash));
                  },
                  onElse: (error) {
                    update(_Value3(_Left(error)));
                  },
                  onThen: (next) {
                    switch (next) {
                      case _NextTailRec(state: final state):
                        update(_Value1(state));
                      case _DoneTailRec(
                          result: final result
                        ):
                        update(_Value3(_Right(result)));
                    }
                  },
                ),
              );
            });
          })._ifCrash((crash) {
            update(_Value2(crash));
          });
        },
        escape: (outcome) {
          switch (outcome) {
            case _Left(value: final crash):
              observer.onCrash(crash);
            case _Right(value: final result):
              switch (result) {
                case _Left(value: final error):
                  observer.onElse(error);
                case _Right(value: final value):
                  observer.onThen(value);
              }
          }
        },
      );
      return cancellers.cancel;
    });
  }

  /// Creates a [Cont] that immediately terminates on the else (error) channel.
  ///
  /// Used to represent business-logic failure states.
  ///
  /// - [err]: The error value to terminate with.
  static Cont<E, F, A> error<E, F, A>(F err) {
    return Cont.fromRun((env, observer) {
      observer.onElse(err);
      return _voidIgnore;
    });
  }

  /// Retrieves the current environment value.
  ///
  /// Accesses the environment of type [E] the continuation runs with.
  /// This is used to read configuration, dependencies, or any contextual
  /// information that flows through the continuation execution.
  ///
  /// Returns a continuation that succeeds with the environment value.
  static Cont<E, F, E> askThen<E, F>() {
    return Cont.fromRun((env, observer) {
      observer.onThen(env);
      return _voidIgnore;
    });
  }

  /// Retrieves the current environment value as an else (error).
  ///
  /// Accesses the environment of type [E] the continuation runs with and
  /// immediately terminates on the else channel with it. Useful for
  /// threading context into error-handling paths.
  ///
  /// Returns a continuation that terminates with the environment value.
  static Cont<E, E, A> askElse<E, A>() {
    return Cont.fromRun((env, observer) {
      observer.onElse(env);
      return _voidIgnore;
    });
  }

  /// Runs two continuations and combines their results according to the specified policy.
  ///
  /// Executes both continuations. Both must succeed for the result to be successful;
  /// if either fails or crashes, the entire operation fails or crashes. When both
  /// succeed, their values are combined using [combine].
  ///
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Runs [left], then [right] only if [left] succeeded.
  /// - [RunAllOkPolicy]: Runs both in parallel, waits for both to complete,
  ///   and merges errors if both fail.
  /// - [QuitFastOkPolicy]: Runs both in parallel, terminates immediately if
  ///   either fails or crashes.
  ///
  /// - [left]: First continuation to execute.
  /// - [right]: Second continuation to execute.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, F, A3> both<E, F, A1, A2, A3>(
    Cont<E, F, A1> left,
    Cont<E, F, A2> right,
    A3 Function(A1 a, A2 a2) combine, {
    required OkPolicy<F> policy,
  }) {
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
  /// - [SequenceOkPolicy]: Runs continuations one by one in order, stops at
  ///   first failure or crash.
  /// - [RunAllOkPolicy]: Runs all in parallel, waits for all to complete,
  ///   and merges errors if any fail. Values and errors are collected in
  ///   completion order, and crashes are reported as a [CollectedCrash].
  /// - [QuitFastOkPolicy]: Runs all in parallel, terminates immediately on
  ///   first failure or crash.
  ///
  /// [SequenceOkPolicy] and [QuitFastOkPolicy] keep list order. An empty
  /// [list] succeeds with `[]`.
  ///
  /// - [list]: List of continuations to execute.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, F, List<A>> all<E, F, A>(
    List<Cont<E, F, A>> list, {
    required OkPolicy<F> policy,
  }) {
    switch (policy) {
      case SequenceOkPolicy():
        return _allSequence(list);
      case QuitFastOkPolicy():
        return _quitFastAll(list);
      case RunAllOkPolicy(
          combine: final combine,
          shouldFavorCrash: final shouldFavorCrash,
        ):
        return _whenAllAll(list, combine, shouldFavorCrash);
    }
  }

  /// Races two continuations, returning the first successful value.
  ///
  /// Executes both continuations and returns the result from whichever succeeds first.
  /// If both fail, their errors are combined via [combine]. A crash ends the race,
  /// like a success. The execution behavior depends on the provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Tries [left] first, then [right] only if [left] fails.
  /// - [RunAllOkPolicy]: Runs both in parallel; if both succeed, combines their
  ///   values using the policy's combine function; otherwise propagates the
  ///   success or merges errors if both fail.
  /// - [QuitFastOkPolicy]: Runs both in parallel, returns immediately on first
  ///   success or crash. A failure waits for the other side.
  ///
  /// - [left]: First continuation to try.
  /// - [right]: Second continuation to try.
  /// - [combine]: Function to combine errors when both continuations fail.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, F3, A> either<E, F1, F2, F3, A>(
    Cont<E, F1, A> left,
    Cont<E, F2, A> right,
    F3 Function(F1, F2) combine, {
    required OkPolicy<A> policy,
  }) {
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
  /// If all fail, their errors are collected into a [List]. A crash ends the race,
  /// like a success. The execution behavior depends on the provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Tries continuations one by one in order until one
  ///   succeeds or crashes.
  /// - [RunAllOkPolicy]: Runs all in parallel; if multiple succeed, combines their
  ///   values using the policy's combine function; otherwise returns the success
  ///   or collects all errors if all fail. Errors are collected in completion
  ///   order, and crashes are reported as a [CollectedCrash].
  /// - [QuitFastOkPolicy]: Runs all in parallel, returns immediately on first
  ///   success or crash.
  ///
  /// [SequenceOkPolicy] and [QuitFastOkPolicy] keep list order. An empty
  /// [list] fails with `[]`.
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
      case RunAllOkPolicy<A>(
          combine: final combine,
          shouldFavorCrash: final shouldFavorCrash,
        ):
        return _whenAllAny(list, combine, shouldFavorCrash);
    }
  }

  /// Runs two continuations and coalesces their crash paths.
  ///
  /// Executes both continuations and combines crashes according to the [policy].
  /// Non-crash outcomes (success and error) are handled according to the policy
  /// when both continuations produce them.
  ///
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [SequenceCrashPolicy]: Runs [left], then [right] only if [left] crashes;
  ///   if both crash, produces a [MergedCrash].
  /// - [QuitFastCrashPolicy]: Runs both in parallel, propagates the first success
  ///   or error immediately. A crash waits for the other side; if both crash,
  ///   produces a [MergedCrash].
  /// - [RunAllCrashPolicy]: Runs both in parallel, waits for both, and merges
  ///   the crashes into a [MergedCrash] if both crash. If either succeeds or
  ///   fails, the crashes are dropped.
  ///
  /// - [left]: First continuation to execute.
  /// - [right]: Second continuation to execute.
  /// - [policy]: Crash policy determining how crashes are coalesced.
  static Cont<E, F, A> coalesce<E, F, A>(
    Cont<E, F, A> left,
    Cont<E, F, A> right, {
    required CrashPolicy<F, A> policy,
  }) {
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
      case RunAllCrashPolicy(
          shouldFavorElse: final shouldFavorElse,
          combineElseVals: final combineElseVals,
          combineThenVals: final combineThenVals,
        ):
        return _crashWhenAll(
          left,
          right,
          combineThenVals,
          combineElseVals,
          shouldFavorElse,
        );
    }
  }

  /// Runs multiple continuations and converges their crash paths.
  ///
  /// Executes all continuations in [list] and combines their crashes according
  /// to the [policy]. Non-crash outcomes are handled per-policy when produced
  /// by multiple continuations.
  ///
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [SequenceCrashPolicy]: Runs continuations one by one, each only if the
  ///   previous one crashed; if all crash, produces a [CollectedCrash].
  /// - [QuitFastCrashPolicy]: Runs all in parallel, propagates the first success
  ///   or error immediately. Crashes wait for the others; if all crash,
  ///   produces a [CollectedCrash].
  /// - [RunAllCrashPolicy]: Runs all in parallel, waits for all, and collects
  ///   crashes into a [CollectedCrash] if all crash. If any continuation
  ///   succeeds or fails, the crashes are dropped.
  ///
  /// An empty [list] crashes with an empty [CollectedCrash].
  ///
  /// - [list]: List of continuations to execute.
  /// - [policy]: Crash policy determining how crashes are converged.
  static Cont<E, F, A> converge<E, F, A>(
    List<Cont<E, F, A>> list, {
    required CrashPolicy<F, A> policy,
  }) {
    switch (policy) {
      case SequenceCrashPolicy():
        return _convergeSequence(list);
      case QuitFastCrashPolicy():
        return _convergeCrashQuitFast(list);
      case RunAllCrashPolicy(
          shouldFavorElse: final shouldFavorElse,
          combineElseVals: final combineElseVals,
          combineThenVals: final combineThenVals,
        ):
        return _convergeCrashRunAll(
          list,
          combineThenVals,
          combineElseVals,
          shouldFavorElse,
        );
    }
  }

  /// Acquires a resource, uses it, and releases it.
  ///
  /// Runs [acquire], passes the resource to [use], and once [use] reports any
  /// outcome (success, error or crash), forwards that outcome and runs
  /// [release] with the resource.
  ///
  /// - [acquire]: Obtains the resource. Cannot produce a business-logic error
  ///   (error type is [Never]); it can only succeed or crash.
  /// - [release]: Releases the resource. Cannot produce a business-logic error
  ///   (error type is [Never]); it can only succeed or crash. Release is
  ///   fire-and-forget: the [use] outcome is forwarded first and [release]
  ///   runs independently. Its outcomes go to [onReleasePanic],
  ///   [onReleaseCrash] and [onReleaseThen].
  /// - [use]: Uses the resource; may succeed with [A], fail with [F], or crash.
  ///
  /// A throw from [use] is a crash, and [release] still runs. If [acquire]
  /// crashes, neither [use] nor [release] runs.
  ///
  /// Release failures are routed two ways: a throw from the [release] function
  /// itself, or from [onReleaseCrash] or [onReleaseThen], goes to
  /// [onReleasePanic]; a crash inside the continuation it returns goes to
  /// [onReleaseCrash]. By default [onReleasePanic] rethrows the panic in a
  /// microtask, and [onReleaseCrash] and [onReleaseThen] do nothing.
  ///
  /// Cancellation: a cancel is forwarded to [use] only. [acquire] and
  /// [release] are never cancelled. A cancel that arrives while [acquire]
  /// runs is applied to [use] as soon as it starts. [release] runs once
  /// [use] reports back, on any channel; if [use] never reports, [release]
  /// never runs.
  static Cont<E, F, A> bracket<R, E, F, A>({
    required Cont<E, Never, R> acquire,
    required Cont<E, Never, ()> Function(R resource)
        release,
    required Cont<E, F, A> Function(R resource) use,
    void Function(NormalCrash crash) onReleasePanic =
        _panic,
    void Function(ContCrash crash) onReleaseCrash = _ignore,
    void Function() onReleaseThen = _voidIgnore,
  }) {
    return Cont.fromRun((env, observer) {
      // acquire is never cancelled: a cancel that arrives while it runs
      // is applied to use as soon as use starts
      final cancellers = _Cancellers();
      acquire.elseAbsurd<F>().runWith(
        env,
        observer.copyUpdateOnThen<R>((resource) {
          bool isReleased = false;

          void fireRelease() {
            if (isReleased) {
              return;
            }
            isReleased = true;

            ContCrash.tryCatch(() {
              release(resource).run(
                env,
                onPanic: onReleasePanic,
                onCrash: onReleaseCrash,
                onThen: (_) => onReleaseThen(),
              );
            })._ifCrash((panic) {
              // a throw from onReleasePanic must not reach use's
              // callbacks; rethrow the release panic, as fromRun
              // does when onPanic throws
              ContCrash.tryCatch(() {
                onReleasePanic(panic);
              })._ifCrash((_) {
                _panic(panic);
              });
            });
          }

          ContCrash.tryCatch(() {
            final contUse = use(resource);
            cancellers.runNext(() {
              return contUse.runWith(
                env,
                observer.copyUpdate(
                  onCrash: (crash) {
                    observer.onCrash(crash);
                    fireRelease();
                  },
                  onElse: (error) {
                    observer.onElse(error);
                    fireRelease();
                  },
                  onThen: (value) {
                    observer.onThen(value);
                    fireRelease();
                  },
                ),
              );
            });
          })._ifCrash((crash) {
            observer._crashOrPanic(crash);
            fireRelease();
          });
        }),
      );
      return cancellers.cancel;
    });
  }
}

/// Provides [runWith], the low-level way to run a [Cont].
///
/// It is an extension rather than a method of [Cont] so that Dart does
/// not check the observer against the [Cont]'s runtime type arguments.
/// That check would reject a valid observer when the [Cont] is used
/// through a wider type, for example a `Cont<E, String, int>` used as a
/// `Cont<E, Object?, int>`.
extension ContRunWithExtension<E, F, A> on Cont<E, F, A> {
  /// Executes the continuation with the given environment and observer
  /// directly.
  ///
  /// Lower-level alternative to [Cont.run]. Useful when composing continuations
  /// internally or when an environment and a [ContObserver] are already
  /// available from an enclosing computation.
  ///
  /// - [env]: The environment to run the continuation with.
  /// - [observer]: The observer whose callbacks receive the computation's outcome.
  ///
  /// Returns the canceller of the started computation.
  void Function() runWith(
    E env,
    ContObserver<F, A> observer,
  ) {
    final self = this;
    if (self is _LeafCont<E, F, A>) {
      // a leaf needs no loop
      return self._run(
        env,
        observer._onUnsafePanic,
        observer.onCrash,
        observer.onElse,
        observer.onThen,
      );
    }
    return _RunLoop(
      env,
      observer._onUnsafePanic,
      observer.onCrash,
      (error) {
        observer.onElse(error as F);
      },
      (value) {
        observer.onThen(value as A);
      },
    ).start(self);
  }
}
