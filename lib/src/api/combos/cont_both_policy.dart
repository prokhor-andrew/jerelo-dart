/// Execution policy for parallel continuation operations.
///
/// Defines how multiple continuations should be executed and how their results
/// or errors should be combined. Different policies provide different trade-offs
/// between execution order, error handling, and result combination.
///
/// Three policies are available:
/// - [BothSequencePolicy]: Executes operations sequentially, one after another.
/// - [BothMergeWhenAllPolicy]: Waits for all operations to complete and merges errors if any fail.
/// - [BothQuitFastPolicy]: Terminates as soon as one operation fails.
sealed class ContBothPolicy {
  const ContBothPolicy();

  /// Creates a sequential execution policy.
  ///
  /// Operations are executed one after another in order.
  /// Execution stops at the first failure.
  static ContBothPolicy sequence() {
    return BothSequencePolicy();
  }

  /// Creates a merge-when-all policy.
  ///
  /// All operations are executed in parallel and all must complete.
  /// For `all`/`both` operations, errors from all failed operations are
  /// concatenated into a single error list.
  static ContBothPolicy mergeWhenAll() {
    return BothMergeWhenAllPolicy();
  }

  /// Creates a quit-fast policy.
  ///
  /// Terminates immediately on the first failure.
  ///
  /// Provides the fastest feedback but may leave other operations running.
  static ContBothPolicy quitFast() {
    return BothQuitFastPolicy();
  }
}

/// Sequential execution policy.
///
/// Executes continuations one after another in order. Stops at the first
/// failure for `all`/`both` operations.
final class BothSequencePolicy extends ContBothPolicy {
  const BothSequencePolicy();
}

/// Merge-when-all execution policy.
///
/// Executes all continuations in parallel and waits for all to complete.
/// Concatenates errors if multiple operations fail.
final class BothMergeWhenAllPolicy extends ContBothPolicy {
  const BothMergeWhenAllPolicy();
}

/// Quit-fast execution policy.
///
/// Terminates as soon as the first failure occurs.
///
/// Provides fastest feedback but other operations may continue running.
final class BothQuitFastPolicy extends ContBothPolicy {
  const BothQuitFastPolicy();
}
