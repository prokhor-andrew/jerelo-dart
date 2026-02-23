/// Controls how two or more continuations on the crash channel are executed
/// and how their crashes are merged.
///
/// Pass a [CrashPolicy] to [Cont.merge] or [Cont.mergeAll] via the named
/// `policy` parameter. Use the static factory methods [sequence], [quitFast],
/// or [runAll] to construct a policy.
sealed class CrashPolicy<E, A> {
  const CrashPolicy();

  /// Sequential crash-merging policy.
  ///
  /// Continuations are run one after another. If both crash, the crashes are
  /// combined into a [MergedCrash].
  static CrashPolicy<E, A> sequence<E, A>() {
    return SequenceCrashPolicy();
  }

  /// Parallel quit-fast crash policy.
  ///
  /// All continuations are started in parallel. As soon as one crashes, the
  /// overall computation propagates that crash immediately without waiting
  /// for the others.
  static CrashPolicy<E, A> quitFast<E, A>() {
    return QuitFastCrashPolicy();
  }

  /// Parallel run-all crash policy.
  ///
  /// All continuations run in parallel and the computation waits for all of
  /// them. Crashes from multiple continuations are merged. When multiple
  /// non-crash outcomes occur, they are combined using [combineElseVals] or
  /// [combineThenVals] as appropriate.
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

/// Sequential crash-merging policy for [Cont.merge] and [Cont.mergeAll].
///
/// Continuations are run sequentially; if both crash, crashes are combined
/// into a [MergedCrash]. See [CrashPolicy.sequence].
final class SequenceCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  const SequenceCrashPolicy();
}

/// Parallel quit-fast crash policy for [Cont.merge] and [Cont.mergeAll].
///
/// Continuations run concurrently; the first crash short-circuits the rest.
/// See [CrashPolicy.quitFast].
final class QuitFastCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  const QuitFastCrashPolicy();
}

/// Parallel run-all crash policy for [Cont.merge] and [Cont.mergeAll].
///
/// Continuations run concurrently and the computation waits for all of them.
/// Multiple crashes are merged; multiple non-crash outcomes are combined via
/// [combineElseVals] and [combineThenVals]. See [CrashPolicy.runAll].
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
