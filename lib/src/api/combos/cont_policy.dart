/// Execution policy for parallel continuation operations.
///
/// Defines how multiple continuations should be executed and how their results
/// or errors should be combined. Different policies provide different trade-offs
/// between execution order, error handling, and result combination.
///
/// Three policies are available:
/// - [SequencePolicy]: Executes operations sequentially, one after another.
/// - [MergeWhenAllPolicy]: Waits for all operations to complete and merges results if multiple succeed.
/// - [QuitFastPolicy]: Terminates as soon as one operation succeeds.
sealed class ContPolicy<A> {
  const ContPolicy();

  /// Creates a sequential execution policy.
  ///
  /// Operations are executed one after another in order.
  /// Execution continues until one succeeds or all fail.
  static ContPolicy<A> sequence<A>() {
    return SequencePolicy();
  }

  /// Creates a merge-when-all policy with a custom combiner.
  ///
  /// All operations are executed in parallel. If multiple operations succeed,
  /// their results are combined using the provided [combine] function.
  /// The function receives the accumulated value and the new value, returning
  /// the combined result.
  ///
  /// - [combine]: Function to merge accumulated and new values.
  static ContPolicy<A> mergeWhenAll<A>(
    A Function(A a1, A a2) combine,
  ) {
    return MergeWhenAllPolicy(combine);
  }

  /// Creates a quit-fast policy.
  ///
  /// Terminates immediately on the first success.
  ///
  /// Provides the fastest feedback but may leave other operations running.
  static ContPolicy<A> quitFast<A>() {
    return QuitFastPolicy();
  }
}

/// Sequential execution policy.
///
/// Executes continuations one after another in order.
/// Continues until the first success or all operations fail.
final class SequencePolicy<A> extends ContPolicy<A> {
  const SequencePolicy();
}

/// Merge-when-all execution policy.
///
/// Executes all continuations in parallel and waits for all to complete.
/// Combines multiple successful results using the provided combine function.
final class MergeWhenAllPolicy<A> extends ContPolicy<A> {
  final A Function(A a1, A a2) combine;
  const MergeWhenAllPolicy(this.combine);
}

/// Quit-fast execution policy.
///
/// Terminates as soon as the first success occurs.
///
/// Provides fastest feedback but other operations may continue running.
final class QuitFastPolicy<A> extends ContPolicy<A> {
  const QuitFastPolicy();
}
