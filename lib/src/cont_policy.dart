/// Execution policy for parallel continuation operations.
///
/// Defines how multiple continuations should be executed and how their results
/// or errors should be combined. Different policies provide different trade-offs
/// between execution order, error handling, and result combination.
///
/// Three policies are available:
/// - [SequencePolicy]: Executes operations sequentially, one after another.
/// - [MergeWhenAllPolicy]: Waits for all operations to complete and merges errors (for `all`/`both`) or results (for `any`/`either`).
/// - [QuitFastPolicy]: Terminates as soon as one operation fails (for `all`/`both`)
///   or succeeds (for `any`/`either`).
sealed class ContPolicy<T> {
  const ContPolicy();

  /// Creates a sequential execution policy.
  ///
  /// Operations are executed one after another in order. For `all`/`both`,
  /// execution stops at the first failure. For `any`/`either`, execution
  /// continues until one succeeds or all fail.
  static ContPolicy<T> sequence<T>() {
    return SequencePolicy();
  }

  /// Creates a merge-when-all policy with a custom combiner.
  ///
  /// All operations are executed in parallel. Results or errors are accumulated
  /// using the provided [combine] function. The function receives the accumulated
  /// value and the new value, returning the combined result.
  ///
  /// - [combine]: Function to merge accumulated and new values.
  static MergeWhenAllPolicy<T> mergeWhenAll<T>(
    T Function(T acc, T value) combine,
  ) {
    return MergeWhenAllPolicy(combine);
  }

  /// Creates a quit-fast policy.
  ///
  /// Terminates immediately when a decisive result is reached:
  /// - For `all`/`both`: quits on the first failure.
  /// - For `any`/`either`: quits on the first success.
  ///
  /// Provides the fastest feedback but may leave other operations running.
  static ContPolicy<T> quitFast<T>() {
    return QuitFastPolicy();
  }
}

/// Sequential execution policy.
///
/// Executes continuations one after another in order. Stops at the first
/// failure for `all`/`both` operations, or at the first success for
/// `any`/`either` operations.
final class SequencePolicy<T> extends ContPolicy<T> {
  const SequencePolicy();
}

/// Merge-when-all execution policy.
///
/// Executes all continuations in parallel and waits for all to complete.
/// Combines results or errors using the provided [combine] function.
final class MergeWhenAllPolicy<T> extends ContPolicy<T> {
  /// Function to combine accumulated and new values.
  final T Function(T acc, T value) combine;

  const MergeWhenAllPolicy(this.combine);
}

/// Quit-fast execution policy.
///
/// Terminates as soon as a decisive result is reached:
/// - For `all`/`both`: terminates on first failure.
/// - For `any`/`either`: terminates on first success.
///
/// Provides fastest feedback but other operations may continue running.
final class QuitFastPolicy<T> extends ContPolicy<T> {
  const QuitFastPolicy();
}
