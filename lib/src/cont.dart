import 'dart:async';

import 'package:jerelo/jerelo.dart';

part 'api/combos/and.dart';
part 'api/combos/or.dart';
part 'api/cont_observer.dart';
part 'api/cont_runtime.dart';
part 'api/decor/decor.dart';
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
part 'helper/all_helpers.dart';
part 'helper/any_helpers.dart';
part 'helper/both_helpers.dart';
part 'helper/constructor_helpers.dart';
part 'helper/either.dart';
part 'helper/either_helpers.dart';
part 'helper/else_helpers.dart';
part 'helper/functions.dart';
part 'helper/loop_helpers.dart';
part 'helper/resource_helpers.dart';
part 'helper/stack_safe_loop_policy.dart';
part 'helper/then_helpers.dart';

/// A continuation monad representing a computation that will eventually
/// produce a value of type [A] or terminate with errors.
///
/// A run delivers its outcome on at most one of these channels: a cancelled
/// run, or a `*Forever` loop that never stops, delivers nothing.
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
  // The callbacks are passed as plain function types rather than as a
  // ContObserver<A>. Dart treats class type parameters as covariant,
  // but checks function types soundly, so this keeps Cont safely
  // covariant in A: a Cont<E, int> can be used as a Cont<E, Object?>.
  // Use the [_run] extension method to run it with an observer.
  final void Function(
    ContRuntime<E> runtime,
    void Function(List<ContError> errors) onElse,
    void Function(A value) onThen,
  )
  _runCallbacks;

  const Cont._(this._runCallbacks);

  /// Creates a [Cont] from a run function that accepts an observer.
  ///
  /// Constructs a continuation with guaranteed idempotence. If [run] throws
  /// synchronously, the error is caught and the continuation terminates with
  /// it. A throw in a callback that runs later, such as a `Timer` or `Future`
  /// callback, is not caught: it escapes as an unhandled exception and the
  /// observer is never called, so catch such errors and pass them to `onElse`.
  /// The run function receives an observer with `onThen` and `onElse` callbacks.
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
      observer.onThen(value);
    });
  }

  /// Creates a [Cont] that immediately terminates with optional errors.
  ///
  /// Creates a continuation that terminates without producing a value.
  /// Used to represent failure states.
  ///
  /// - [errors]: List of errors to terminate with. Defaults to an empty list.
  static Cont<E, A> stop<E, A>([
    List<ContError> errors = const [],
  ]) {
    errors = errors.toList();
    return Cont.fromRun((runtime, observer) {
      errors = errors
          .toList(); // if same computation ran twice, and got list modified, it won't affect the other one
      observer.onElse(errors);
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
      observer.onThen(runtime.env());
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
  static Cont<E, A> askThen<E, A>(
    Cont<E, A> Function(E env) f,
  ) {
    return Cont.ask<E>().thenDo(f);
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
  ///   and merges errors if both fail. The errors of the side that failed first
  ///   come first.
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
  ///   and merges errors if any fail. Values and errors are collected in
  ///   completion order, not list order. Tag the results if you need to know
  ///   which continuation produced them.
  /// - [BothQuitFastPolicy]: Runs all in parallel, terminates immediately on first failure.
  ///
  /// [BothSequencePolicy] and [BothQuitFastPolicy] collect values in list order.
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
  /// Executes both continuations and returns a successful value if either succeeds.
  /// If both fail, concatenates their errors, those of [left] first. The execution
  /// behavior depends on the provided [policy]:
  ///
  /// - [EitherSequencePolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [EitherMergeWhenAllPolicy]: Runs both in parallel and waits for both to
  ///   complete; there is no early return on the first success. If only one
  ///   succeeds, returns its value. If both succeed, merges them using the
  ///   policy's combine function, with the value that arrived first as the
  ///   first argument.
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
            return Cont.stop(errors1 + errors2);
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
  /// Executes all continuations in [list] and returns a successful value if any
  /// succeeds. If all fail, collects all errors. The execution behavior depends
  /// on the provided [policy]:
  ///
  /// - [EitherSequencePolicy]: Tries continuations one by one in order until one succeeds.
  /// - [EitherMergeWhenAllPolicy]: Runs all in parallel and waits for all to
  ///   complete; there is no early return on the first success. Merges the
  ///   successful values using the policy's combine function in completion
  ///   order. If all fail, errors are collected in completion order.
  /// - [EitherQuitFastPolicy]: Runs all in parallel, returns immediately on first success.
  ///
  /// [EitherSequencePolicy] and [EitherQuitFastPolicy] collect errors in list
  /// order.
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
  /// even if an error occurs during the [use] phase. Cancellation has limits,
  /// described below.
  /// This is the functional equivalent of try-with-resources or using statements.
  ///
  /// The execution order is:
  /// 1. [acquire] - Obtain the resource
  /// 2. [use] - Use the resource to produce a value
  /// 3. [release] - Release the resource (runs when [use] finishes, whether it succeeds or fails)
  ///
  /// Cancellation behavior:
  /// - If the computation is cancelled before [use] starts, [use] is skipped
  ///   and [release] still runs.
  /// - [release] runs on a runtime that is never cancelled, so cancellation
  ///   does not stop it once it has started.
  ///
  /// Limits under cancellation. Cancellation is cooperative and nothing is
  /// notified when it happens, so [bracket] only learns about it when [use]
  /// delivers a result:
  /// - Cancelled while [use] runs → a cancelled computation stops without
  ///   delivering anything, and a result that arrives after the cancellation
  ///   is dropped. [use] therefore never reports back, [release] never runs,
  ///   and the resource is not released.
  /// - Cancelled while [acquire] runs → [acquire] can stop the same way
  ///   after it has obtained the resource, which is then never released.
  ///
  /// These limits are part of the 1.x cancellation design and are not fixed
  /// in 1.x.
  ///
  /// Error handling behavior:
  /// - If [use] succeeds and [release] succeeds: returns the value from [use]
  /// - If [use] succeeds and [release] fails: terminates with release errors
  /// - If [use] fails and [release] succeeds: terminates with use errors
  /// - If [use] fails and [release] fails: terminates with both errors combined
  ///
  /// Example:
  /// ```dart
  /// final result = Cont.bracket<(), File, String>(
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

/// Runs a [Cont] with an observer.
///
/// It is an extension rather than a method of [Cont] so that Dart does
/// not check the observer against the [Cont]'s runtime type arguments.
/// That check would reject a valid observer when the [Cont] is used
/// through a wider type, for example a `Cont<E, int>` used as a
/// `Cont<E, Object?>`.
extension _ContRunExtension<E, A> on Cont<E, A> {
  void _run(
    ContRuntime<E> runtime,
    ContObserver<A> observer,
  ) {
    _runCallbacks(runtime, observer._onElse, observer.onThen);
  }
}
