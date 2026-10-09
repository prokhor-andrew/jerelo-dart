/// Controls how two or more continuations on the crash channel are executed
/// and how their crashes are merged.
///
/// Pass a [CrashPolicy] to [Cont.coalesce] or [Cont.converge] via the named
/// `policy` parameter. Use the static factory methods [sequence], [quitFast],
/// or [runAll] to construct a policy.
///
/// The crash channel is the own channel of these combinators: they wait for
/// crashes and treat a success or an error as an exit.
sealed class CrashPolicy<E, A> {
  const CrashPolicy();

  /// Sequential crash-merging policy.
  ///
  /// Continuations are run one after another; the next one runs only if the
  /// previous one crashed. The first success or error ends the computation.
  /// If all crash, the crashes are combined into a [MergedCrash]
  /// ([Cont.coalesce]) or a [CollectedCrash] ([Cont.converge]).
  static CrashPolicy<E, A> sequence<E, A>() {
    return SequenceCrashPolicy();
  }

  /// Parallel quit-fast crash policy.
  ///
  /// All continuations are started in parallel. As soon as one succeeds or
  /// fails, the overall computation propagates that outcome immediately
  /// without waiting for the others. A crash waits for the others; if all
  /// crash, the crashes are combined into a [MergedCrash] ([Cont.coalesce])
  /// or a [CollectedCrash] ([Cont.converge]).
  static CrashPolicy<E, A> quitFast<E, A>() {
    return QuitFastCrashPolicy();
  }

  /// Parallel run-all crash policy.
  ///
  /// All continuations run in parallel and the computation waits for all of
  /// them. Crashes are only propagated if all continuations crash; they are
  /// then merged. If any continuation succeeds or fails, the crashes are
  /// dropped. When multiple non-crash outcomes occur, they are combined
  /// using [combineElseVals] or [combineThenVals] as appropriate.
  ///
  /// - [shouldFavorElse]: When `true`, an else (error) outcome is favored over
  ///   a then (success) outcome when both occur.
  /// - [combineElseVals]: Function to merge two else values of type [E].
  /// - [combineThenVals]: Function to merge two then values of type [A].
  static CrashPolicy<E, A> runAll<E, A>({
    required bool shouldFavorElse,
    required E Function(E e1, E e2) combineElseVals,
    required A Function(A a1, A a2) combineThenVals,
  }) {
    return RunAllCrashPolicy(
      shouldFavorElse: shouldFavorElse,
      combineElseVals: combineElseVals,
      combineThenVals: combineThenVals,
    );
  }
}

/// Sequential crash-merging policy for [Cont.coalesce] and [Cont.converge].
///
/// Continuations are run sequentially, each only if the previous one
/// crashed; if all crash, crashes are combined into a [MergedCrash]
/// ([Cont.coalesce]) or a [CollectedCrash] ([Cont.converge]).
/// See [CrashPolicy.sequence].
final class SequenceCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  const SequenceCrashPolicy();
}

/// Parallel quit-fast crash policy for [Cont.coalesce] and [Cont.converge].
///
/// Continuations run concurrently; the first success or error
/// short-circuits the rest, while crashes wait for the others.
/// See [CrashPolicy.quitFast].
final class QuitFastCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  const QuitFastCrashPolicy();
}

/// Parallel run-all crash policy for [Cont.coalesce] and [Cont.converge].
///
/// Continuations run concurrently and the computation waits for all of them.
/// Crashes are merged only if all continuations crash; multiple non-crash
/// outcomes are combined via [combineElseVals] and [combineThenVals].
/// See [CrashPolicy.runAll].
final class RunAllCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  /// When `true`, an else (error) outcome is preferred over a then (success)
  /// outcome when both occur simultaneously.
  final bool shouldFavorElse;

  /// Function to merge two else (error) values of type [E].
  final E Function(E e1, E e2) combineElseVals;

  /// Function to merge two then (success) values of type [A].
  final A Function(A a1, A a2) combineThenVals;

  const RunAllCrashPolicy({
    required this.shouldFavorElse,
    required this.combineElseVals,
    required this.combineThenVals,
  });
}
