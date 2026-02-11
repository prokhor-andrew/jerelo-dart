import 'dart:async';
import 'dart:math';

import 'package:jerelo/jerelo.dart';

part 'helper/either.dart';
part 'helper/stack_safe_loop_policy.dart';
part 'helper/both_helpers.dart';
part 'helper/either_helpers.dart';
part 'helper/all_helpers.dart';
part 'helper/any_helpers.dart';
part 'helper/constructor_helpers.dart';
part 'helper/then_helpers.dart';
part 'helper/else_helpers.dart';
part 'helper/loop_helpers.dart';
part 'helper/resource_helpers.dart';
part 'helper/functions.dart';
part 'api/cont_observer.dart';
part 'api/cont_runtime.dart';
part 'api/run/cont_cancel_token.dart';
part 'api/decor/decor.dart';
part 'api/run/run.dart';
part 'api/run/ff.dart';
part 'api/then/map.dart';
part 'api/extensions/never.dart';
part 'api/extensions/flatten.dart';
part 'api/env/env.dart';
part 'api/then/do.dart';
part 'api/then/tap.dart';
part 'api/then/fork.dart';
part 'api/then/zip.dart';
part 'api/then/if.dart';
part 'api/then/while.dart';
part 'api/then/until.dart';
part 'api/then/abort.dart';
part 'api/then/forever.dart';
part 'api/else/do.dart';
part 'api/else/tap.dart';
part 'api/else/fork.dart';
part 'api/else/zip.dart';
part 'api/else/if.dart';
part 'api/else/while.dart';
part 'api/else/until.dart';
part 'api/else/map.dart';
part 'api/else/recover.dart';
part 'api/combos/or.dart';
part 'api/combos/and.dart';

/// A continuation monad representing a computation that will eventually
/// produce a value of type [A] or terminate with errors.
///
/// [Cont] provides a powerful abstraction for managing asynchronous operations,
/// error handling, and composition of effectful computations. It follows the
/// continuation-passing style where computations are represented as functions
/// that take callbacks for success and failure.
///
/// Type parameters:
/// - [E]: The environment type providing context for the continuation execution.
/// - [A]: The value type that the continuation produces upon success.
final class Cont<E, A> {
  final void Function(
    ContRuntime<E> runtime,
    ContObserver<A> observer,
  )
  _run;

  const Cont._(this._run);

  /// Creates a [Cont] from a run function that accepts an observer.
  ///
  /// Constructs a continuation with guaranteed idempotence and exception catching.
  /// The run function receives an observer with `onValue` and `onTerminate` callbacks.
  /// The callbacks should be called as the last instruction in the run function
  /// or saved to be called later.
  ///
  /// - [run]: Function that executes the continuation and calls observer callbacks.
  static Cont<E, A> fromRun<E, A>(
    void Function(
      ContRuntime<E> runtime,
      ContObserver<A> observer,
    )
    run,
  ) {
    return _fromRun(run);
  }

  /// Creates a [Cont] from a deferred continuation computation.
  ///
  /// Lazily evaluates a continuation-returning function. The inner [Cont] is
  /// not created until the outer one is executed.
  ///
  /// - [thunk]: Function that returns a [Cont] when called.
  static Cont<E, A> fromDeferred<E, A>(
    Cont<E, A> Function() thunk,
  ) {
    return Cont.fromRun((runtime, observer) {
      Cont<E, A> contA = thunk();
      if (contA is Cont<E, Never>) {
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
  static Cont<E, A> of<E, A>(A value) {
    return Cont.fromRun((runtime, observer) {
      observer.onValue(value);
    });
  }

  /// Creates a [Cont] that immediately terminates with optional errors.
  ///
  /// Creates a continuation that terminates without producing a value.
  /// Used to represent failure states.
  ///
  /// - [errors]: List of errors to terminate with. Defaults to an empty list.
  static Cont<E, A> terminate<E, A>([
    List<ContError> errors = const [],
  ]) {
    errors = errors.toList();
    return Cont.fromRun((runtime, observer) {
      errors = errors
          .toList(); // if same computation ran twice, and got list modified, it won't affect the other one
      observer.onTerminate(errors);
    });
  }

  /// Retrieves the current environment value.
  ///
  /// Accesses the environment of type [E] from the runtime context.
  /// This is used to read configuration, dependencies, or any contextual
  /// information that flows through the continuation execution.
  ///
  /// Returns a continuation that succeeds with the environment value.
  static Cont<E, E> ask<E>() {
    return Cont.fromRun((runtime, observer) {
      observer.onValue(runtime.env());
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
  ///   and merges errors if both fail.
  /// - [BothQuitFastPolicy]: Runs both in parallel, terminates immediately if either fails.
  ///
  /// - [left]: First continuation to execute.
  /// - [right]: Second continuation to execute.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, A3> both<E, A1, A2, A3>(
    Cont<E, A1> left,
    Cont<E, A2> right,
    A3 Function(A1 a, A2 a2) combine, {
    required ContBothPolicy policy,
    //
  }) {
    if (left is Cont<E, Never>) {
      left = left.absurd<A1>();
    }

    if (right is Cont<E, Never>) {
      right = right.absurd<A2>();
    }

    switch (policy) {
      case BothSequencePolicy():
        return left.thenDo((a) {
          return right.thenMap((a2) {
            return combine(a, a2);
          });
        });
      case BothMergeWhenAllPolicy():
        return _bothMergeWhenAll(left, right, combine);
      case BothQuitFastPolicy():
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
  ///   and merges errors if any fail.
  /// - [BothQuitFastPolicy]: Runs all in parallel, terminates immediately on first failure.
  ///
  /// - [list]: List of continuations to execute.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, List<A>> all<E, A>(
    List<Cont<E, A>> list, {
    required ContBothPolicy policy,
    //
  }) {
    list = list.toList(); // defensive copy
    switch (policy) {
      case BothSequencePolicy():
        return _allSequence(list);
      case BothMergeWhenAllPolicy():
        return _allMergeWhenAll(list);
      case BothQuitFastPolicy():
        return _allQuitFast(list);
    }
  }

  /// Races two continuations, returning the first successful value.
  ///
  /// Executes both continuations and returns the result from whichever succeeds first.
  /// If both fail, concatenates their errors. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [EitherSequencePolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [EitherMergeWhenAllPolicy]: Runs both in parallel, returns first success or merges
  ///   results using the policy's combine function if both succeed.
  /// - [EitherQuitFastPolicy]: Runs both in parallel, returns immediately on first success.
  ///
  /// - [left]: First continuation to try.
  /// - [right]: Second continuation to try.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, A> either<E, A>(
    Cont<E, A> left,
    Cont<E, A> right, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    if (left is Cont<E, Never>) {
      left = left.absurd<A>();
    }

    if (right is Cont<E, Never>) {
      right = right.absurd<A>();
    }

    switch (policy) {
      case EitherSequencePolicy<A>():
        return left.elseDo((errors1) {
          return right.elseDo((errors2) {
            return Cont.terminate(errors1 + errors2);
          });
        });
      case EitherMergeWhenAllPolicy<A>(
        combine: final combine,
      ):
        return _eitherMergeWhenAll(left, right, combine);
      case EitherQuitFastPolicy<A>():
        return _eitherQuitFast(left, right);
    }
  }

  /// Races multiple continuations, returning the first successful value.
  ///
  /// Executes all continuations in [list] and returns the first one that succeeds.
  /// If all fail, collects all errors. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [EitherSequencePolicy]: Tries continuations one by one in order until one succeeds.
  /// - [EitherMergeWhenAllPolicy]: Runs all in parallel, returns first success or merges
  ///   results using the policy's combine function if multiple succeed.
  /// - [EitherQuitFastPolicy]: Runs all in parallel, returns immediately on first success.
  ///
  /// - [list]: List of continuations to race.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, A> any<E, A>(
    List<Cont<E, A>> list, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    final List<Cont<E, A>> safeCopy0 =
        List<Cont<E, A>>.from(list);

    switch (policy) {
      case EitherSequencePolicy<A>():
        return _anySequence(safeCopy0);
      case EitherMergeWhenAllPolicy<A>(
        combine: final combine,
      ):
        return _anyMergeWhenAll(safeCopy0, combine);
      case EitherQuitFastPolicy<A>():
        return _anyQuitFast(safeCopy0);
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
  /// - If [use] succeeds and [release] fails: terminates with release errors
  /// - If [use] fails and [release] succeeds: terminates with use errors
  /// - If [use] fails and [release] fails: terminates with both errors combined
  ///
  /// Example:
  /// ```dart
  /// final result = Cont.bracket<File, String>(
  ///   acquire: openFile('data.txt'),           // acquire
  ///   release: (file) => closeFile(file),      // release
  ///   use: (file) => readContents(file),   // use
  /// );
  /// ```
  static Cont<E, A> bracket<E, R, A>({
    required Cont<E, R> acquire,
    required Cont<E, ()> Function(R resource) release,
    required Cont<E, A> Function(R resource) use,
    //
  }) {
    return _bracket(
      acquire: acquire,
      release: release,
      use: use,
    );
  }
}
