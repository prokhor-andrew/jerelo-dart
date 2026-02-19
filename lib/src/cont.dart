import 'dart:async';

import 'package:jerelo/jerelo.dart';

part 'api/combos/and.dart';
part 'api/combos/or.dart';
part 'api/cont_observer.dart';
part 'api/cont_runtime.dart';
part 'api/decorate/decorate.dart';
part 'api/else/do.dart';
part 'api/else/fork.dart';
part 'api/else/if.dart';
part 'api/else/map.dart';
part 'api/else/recover.dart';
part 'api/else/tap.dart';
part 'api/else/until.dart';
part 'api/else/while.dart';
part 'api/else/zip.dart';
part 'api/then/forever.dart';
part 'api/env/env.dart';
part 'api/extensions/flatten.dart';
part 'api/extensions/never.dart';
part 'api/run/cont_cancel_token.dart';
part 'api/run/ff.dart';
part 'api/run/run.dart';
part 'api/then/abort.dart';
part 'api/then/do.dart';
part 'api/else/forever.dart';
part 'api/then/fork.dart';
part 'api/then/if.dart';
part 'api/then/map.dart';
part 'api/then/tap.dart';
part 'api/then/until.dart';
part 'api/then/while.dart';
part 'api/then/zip.dart';
part 'helper/when_all_helpers.dart';
part 'helper/quit_fast_helpers.dart';
part 'helper/constructor_helpers.dart';
part 'helper/utils.dart';
part 'helper/else_helpers.dart';
part 'helper/combine_list_helpers.dart';
part 'helper/loop_helpers.dart';
part 'helper/stack_safe_loop_policy.dart';
part 'helper/then_helpers.dart';
part 'helper/resource_helpers.dart';

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
    return _fromRun(run);
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
      if (contA is Cont<E, F, Never>) {
        contA = contA.absurd<A>();
      }
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
  static Cont<E, F, A> stop<E, F, A>(
    ContError<F> error,
  ) {
    return Cont.fromRun((runtime, observer) {
      observer.onElse(error);
    });
  }

  /// Retrieves the current environment value.
  ///
  /// Accesses the environment of type [E] from the runtime context.
  /// This is used to read configuration, dependencies, or any contextual
  /// information that flows through the continuation execution.
  ///
  /// Returns a continuation that succeeds with the environment value.
  static Cont<E, F, E> ask<E, F>() {
    return Cont.fromRun((runtime, observer) {
      observer.onThen(runtime.env());
    });
  }

  static Cont<E, E, A> ask2<E, A>() {
    return Cont.fromRun((runtime, observer) {
      observer.onElse(ManualError(runtime.env()));
    });
  }

  /// Retrieves the environment and chains a computation that depends on it.
  ///
  /// Convenience method equivalent to `Cont.ask<E>().thenDo(f)`. Reads the
  /// environment of type [E] and immediately passes it to [f], which returns
  /// a continuation to execute next.
  ///
  /// This is the most common pattern when building computations that depend
  /// on the environment, avoiding the need to manually call `ask` and `thenDo`
  /// separately.
  ///
  /// - [f]: Function that takes the environment and returns a continuation.
  static Cont<E, F, A> askThen<E, F, A>(
    Cont<E, F, A> Function(E env) f,
  ) {
    return Cont.ask<E, F>().thenDo(f);
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
    required ContPolicy<ContError<F>> policy,
    //
  }) {
    if (left is Cont<E, F, Never>) {
      left = left.absurd<A1>();
    }

    if (right is Cont<E, F, Never>) {
      right = right.absurd<A2>();
    }

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
    required ContPolicy<ContError<F>> policy,
    //
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
    ContError<F3> Function(ContError<F1>, ContError<F2>)
        combine, {
    required ContPolicy<A> policy,
    //
  }) {
    if (left is Cont<E, F1, Never>) {
      left = left.absurd<A>();
    }

    if (right is Cont<E, F2, Never>) {
      right = right.absurd<A>();
    }

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
  static Cont<E, List<ContError<F>>, A> any<E, F, A>(
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

  /// Manages resource lifecycle with guaranteed cleanup.
  ///
  /// The bracket pattern ensures that a resource is properly released after use,
  /// even if an error occurs during the [use] phase or if cancellation occurs.
  /// This is the functional equivalent of try-with-resources or using statements.
  ///
  /// The execution order is:
  /// 1. [acquire] - Obtain the resource
  /// 2. [use] - Use the resource to produce a value
  /// 3. [release] - Release the resource (always runs, even if [use] fails or is cancelled)
  ///
  /// Cancellation behavior:
  /// - The [release] function is called even when the runtime is cancelled
  /// - This ensures resources are properly cleaned up regardless of cancellation
  /// - However, if cancellation occurs during release itself, cleanup may be partial
  ///
  /// Error handling behavior:
  /// - If [use] succeeds and [release] succeeds: returns the value from [use]
  /// - If [use] succeeds and [release] fails: terminates with release error
  /// - If [use] fails and [release] succeeds: terminates with use error
  /// - If [use] fails and [release] fails: terminates with both error combined
  ///
  /// Example:
  /// ```dart
  /// final result = Cont.bracket<File, String>(
  ///   acquire: openFile('data.txt'),           // acquire
  ///   release: (file) => closeFile(file),      // release
  ///   use: (file) => readContents(file),   // use
  /// );
  /// ```
  static Cont<E, F, A> bracket<E, F, R, A>({
    required Cont<E, F, R> acquire,
    required Cont<E, F, ()> Function(R resource) release,
    required Cont<E, F, A> Function(R resource) use,
    required ContError<F> Function(
      ContError<F> useError,
      ContError<F> releaseError,
    ) combine,
    //
  }) {
    return _bracket(
      acquire: acquire,
      release: release,
      use: use,
      combine: combine,
    );
  }
}
