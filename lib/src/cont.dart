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
part 'helper/utils.dart';

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
final class Cont<E, F, A> {
  // The callbacks are passed as plain function types rather than as a
  // ContObserver<F, A>. Dart treats class type parameters as covariant,
  // but checks function types soundly, so this keeps Cont safely
  // covariant in F and A: a Cont<E, String, int> can be used as a
  // Cont<E, Object?, int>.
  final void Function(
    ContRuntime<E> runtime,
    void Function(NormalCrash crash) onPanic,
    void Function(ContCrash crash) onCrash,
    void Function(F error) onElse,
    void Function(A value) onThen,
  ) _run;

  const Cont._(this._run);

  /// Executes the continuation with the given environment.
  ///
  /// Runs the continuation and routes its outcome to the appropriate callback.
  /// Returns a [ContCancelToken] that can be used to cooperatively cancel
  /// the running computation.
  ///
  /// - [env]: The environment value to provide to the computation.
  /// - [onPanic]: Called when an unexpected exception escapes all crash handlers.
  ///   Defaults to rethrowing the panic.
  /// - [onCrash]: Called when the computation terminates on the crash channel.
  ///   Defaults to silently ignoring the crash.
  /// - [onElse]: Called when the computation terminates on the else (error) channel.
  ///   Defaults to silently ignoring the error.
  /// - [onThen]: Called when the computation succeeds with a value.
  ///   Defaults to silently ignoring the value.
  ContCancelToken run(
    E env, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F error) onElse = _ignore,
    void Function(A value) onThen = _ignore,
  }) {
    final cancelToken = ContCancelToken._();
    cancelToken._node._onPanic = onPanic;

    runWith(
      ContRuntime._(env, cancelToken._node),
      _UnsafeObserver._(onPanic, onCrash, onElse, onThen),
    );

    return cancelToken;
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
    return Cont._((
      runtime,
      onUnsafePanic,
      onCrash,
      onElse,
      onThen,
    ) {
      if (runtime.isCancelled()) {
        return;
      }

      void onPanic(NormalCrash crash) {
        ContCrash.tryCatch(() {
          onUnsafePanic(crash);
        }).match((_) {}, (panic) {
          // the important part here is that if onPanic crashes,
          // we don't push the crash that was sent there,
          // but the crash that caused the onPanic
          _panic(panic);
        });
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

        ContCrash.tryCatch(() {
          onCrash(crash);
        }).match((_) {}, onPanic);
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

        ContCrash.tryCatch(() {
          onElse(error);
        }).match((_) {}, onPanic);
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

        ContCrash.tryCatch(() {
          onThen(a);
        }).match((_) {}, onPanic);
      }

      ContCrash.tryCatch(() {
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
      }).match((_) {}, guardedOnCrash);
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
      Cont<E, F, A> contA = thunk();
      contA.runWith(runtime, observer);
    });
  }

  /// Creates a [Cont] that immediately terminates on the crash channel.
  ///
  /// - [crash]: The [ContCrash] value to propagate.
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

  /// Creates a [Cont] that immediately terminates on the else (error) channel.
  ///
  /// Used to represent business-logic failure states.
  ///
  /// - [err]: The error value to terminate with.
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

  /// Retrieves the current environment value as an else (error).
  ///
  /// Accesses the environment of type [E] from the runtime context and
  /// immediately terminates on the else channel with it. Useful for
  /// threading context into error-handling paths.
  ///
  /// Returns a continuation that terminates with the environment value.
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
  /// - [SequenceOkPolicy]: Runs [left] then [right] sequentially.
  /// - [RunAllOkPolicy]: Runs both in parallel, waits for both to complete,
  ///   and merges errors if both fail.
  /// - [QuitFastOkPolicy]: Runs both in parallel, terminates immediately if either fails.
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
  /// - [SequenceOkPolicy]: Runs continuations one by one in order, stops at first failure.
  /// - [RunAllOkPolicy]: Runs all in parallel, waits for all to complete,
  ///   and merges errors if any fail.
  /// - [QuitFastOkPolicy]: Runs all in parallel, terminates immediately on first failure.
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
  /// If both fail, their errors are combined via [combine]. The execution behavior
  /// depends on the provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [RunAllOkPolicy]: Runs both in parallel; if both succeed, combines their
  ///   values using the policy's combine function; otherwise propagates the first
  ///   success or merges errors if both fail.
  /// - [QuitFastOkPolicy]: Runs both in parallel, returns immediately on first success.
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
  /// If all fail, their errors are collected into a [List]. The execution behavior
  /// depends on the provided [policy]:
  ///
  /// - [SequenceOkPolicy]: Tries continuations one by one in order until one succeeds.
  /// - [RunAllOkPolicy]: Runs all in parallel; if multiple succeed, combines their
  ///   values using the policy's combine function; otherwise returns the first success
  ///   or collects all errors if all fail.
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
  /// - [SequenceCrashPolicy]: Runs [left] then [right] sequentially; if both crash,
  ///   produces a [MergedCrash].
  /// - [QuitFastCrashPolicy]: Runs both in parallel, propagates the first crash
  ///   immediately.
  /// - [RunAllCrashPolicy]: Runs both in parallel, waits for both, and coalesces crashes
  ///   if both crash.
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
              MergedCrash(crash1, crash2),
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
  /// - [SequenceCrashPolicy]: Runs continuations one by one; sequential crashes
  ///   are converged into a [MergedCrash].
  /// - [QuitFastCrashPolicy]: Runs all in parallel, propagates the first crash
  ///   immediately.
  /// - [RunAllCrashPolicy]: Runs all in parallel, waits for all, and collects
  ///   crashes into a [CollectedCrash].
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

  /// Acquires a resource, uses it, and guarantees its release.
  ///
  /// Implements the bracket pattern for safe resource management. Regardless
  /// of whether [use] succeeds, fails, or crashes, [release] is always called
  /// with the acquired resource.
  ///
  /// - [acquire]: Obtains the resource. Cannot produce a business-logic error
  ///   (error type is [Never]); it can only succeed or crash.
  /// - [release]: Releases the resource. Cannot produce a business-logic error
  ///   (error type is [Never]); it can only succeed or crash. Release is
  ///   fire-and-forget: the [use] outcome is propagated immediately and
  ///   [release] runs independently. Release outcomes are routed to the
  ///   optional [onReleasePanic], [onReleaseCrash], and [onReleaseThen]
  ///   callbacks, following the same pattern as fork handlers.
  /// - [use]: Uses the resource; may succeed with [A], fail with [F], or crash.
  ///
  /// Outcome rules:
  /// - [use] succeeded  → propagate the success value immediately.
  /// - [use] failed     → propagate the failure error immediately.
  /// - [use] crashed    → propagate the crash immediately.
  /// - [release] outcomes are routed to the release handlers.
  ///
  /// Cancellation:
  /// - [acquire] always runs to completion, so an acquired resource is
  ///   never lost.
  /// - Cancelled before [use] starts → [release] runs as soon as [acquire]
  ///   completes; the observer receives nothing.
  /// - Cancelled while [use] runs → [release] runs immediately, without
  ///   waiting for [use]. [use] may then fail on the released resource;
  ///   its outcome is dropped.
  /// - [release] runs at most once and is never cancelled.
  static Cont<E, F, A> bracket<R, E, F, A>({
    required Cont<E, Never, R> acquire,
    required Cont<E, Never, ()> Function(
      R resource,
    ) release,
    required Cont<E, F, A> Function(R resource) use,
    void Function(NormalCrash crash) onReleasePanic =
        _panic,
    void Function(ContCrash crash) onReleaseCrash = _ignore,
    void Function() onReleaseThen = _voidIgnore,
  }) {
    return Cont.fromRun((runtime, observer) {
      // acquire always runs to completion, so an acquired resource is
      // never lost to cancellation: if the run was cancelled meanwhile, it
      // is released right away below
      acquire.elseAbsurd<F>().runWith(
        runtime._uncancellable(),
        observer.copyUpdateOnThen<R>((r) {
          bool isReleased = false;

          void fireRelease() {
            if (isReleased) {
              return;
            }
            isReleased = true;

            ContCrash.tryCatch(() {
              release(r).run(
                runtime.env(),
                onPanic: onReleasePanic,
                onCrash: onReleaseCrash,
                onThen: (_) => onReleaseThen(),
              );
            }).match((_) {}, onReleasePanic);
          }

          if (runtime.isCancelled()) {
            fireRelease();
            return;
          }

          // cancellation while use runs releases the resource immediately;
          // use's outcome is then dropped
          final unregister = runtime.onCancel(fireRelease);

          void finish(void Function() forward) {
            unregister();
            if (!runtime.isCancelled()) {
              forward();
            }
            fireRelease();
          }

          ContCrash.tryCatch(() {
            use(r).runWith(
              runtime,
              observer.copyUpdate(
                onCrash: (crash) {
                  finish(() => observer.onCrash(crash));
                },
                onElse: (error) {
                  finish(() => observer.onElse(error));
                },
                onThen: (a) {
                  finish(() => observer.onThen(a));
                },
              ),
            );
          }).match((_) {}, (crash) {
            finish(() => observer.onCrash(crash));
          });
        }),
      );
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
  /// Executes the continuation with the given runtime and observer directly.
  ///
  /// Lower-level alternative to [Cont.run]. Useful when composing continuations
  /// internally or when a [ContRuntime] and [ContObserver] are already
  /// available from an enclosing computation.
  ///
  /// - [runtime]: The runtime context providing the environment and cancellation state.
  /// - [observer]: The observer whose callbacks receive the computation's outcome.
  void runWith(
    ContRuntime<E> runtime,
    ContObserver<F, A> observer,
  ) {
    _run(
      runtime,
      observer._onUnsafePanic,
      observer.onCrash,
      observer.onElse,
      observer.onThen,
    );
  }
}
