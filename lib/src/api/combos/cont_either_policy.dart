/// Execution policy for parallel continuation operations.
///
/// Defines how multiple continuations should be executed and how their results
/// or errors should be combined. Different policies provide different trade-offs
/// between execution order, error handling, and result combination.
///
/// Three policies are available:
/// - [EitherSequencePolicy]: Executes operations sequentially, one after another.
/// - [EitherMergeWhenAllPolicy]: Waits for all operations to complete and merges results if multiple succeed.
/// - [EitherQuitFastPolicy]: Terminates as soon as one operation succeeds.
sealed class ContEitherPolicy<A> {
  const ContEitherPolicy();

  /// Creates a sequential execution policy.
  ///
  /// Operations are executed one after another in order.
  /// Execution continues until one succeeds or all fail.
  static ContEitherPolicy<A> sequence<A>() {
    return EitherSequencePolicy();
  }

  /// Creates a merge-when-all policy with a custom combiner.
  ///
  /// All operations are executed in parallel. If multiple operations succeed,
  /// their results are combined using the provided [combine] function.
  /// The function receives the accumulated value and the new value, returning
  /// the combined result.
  ///
  /// - [combine]: Function to merge accumulated and new values.
  static ContEitherPolicy<A> mergeWhenAll<A>(
    A Function(A a1, A a2) combine,
  ) {
    return EitherMergeWhenAllPolicy(combine);
  }

  /// Creates a quit-fast policy.
  ///
  /// Terminates immediately on the first success.
  ///
  /// Provides the fastest feedback but may leave other operations running.
  static ContEitherPolicy<A> quitFast<A>() {
    return EitherQuitFastPolicy();
  }
}

/// Sequential execution policy.
///
/// Executes continuations one after another in order.
/// Continues until the first success or all operations fail.
final class EitherSequencePolicy<A>
    extends ContEitherPolicy<A> {
  const EitherSequencePolicy();
}

/// Merge-when-all execution policy.
///
/// Executes all continuations in parallel and waits for all to complete.
/// Combines multiple successful results using the provided combine function.
final class EitherMergeWhenAllPolicy<A>
    extends ContEitherPolicy<A> {
  final A Function(A a1, A a2) combine;
  const EitherMergeWhenAllPolicy(this.combine);
}

/// Quit-fast execution policy.
///
/// Terminates as soon as the first success occurs.
///
/// Provides fastest feedback but other operations may continue running.
final class EitherQuitFastPolicy<A>
    extends ContEitherPolicy<A> {
  const EitherQuitFastPolicy();
}
