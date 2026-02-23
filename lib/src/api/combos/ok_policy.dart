/// Controls how two or more continuations on the success/error channels
/// are executed and how their outcomes are combined.
///
/// Pass an [OkPolicy] to [Cont.both], [Cont.all], [Cont.either], or [Cont.any]
/// via the named `policy` parameter. Use the static factory methods
/// [sequence], [quitFast], or [runAll] to construct a policy.
sealed class OkPolicy<T> {
  const OkPolicy();

  /// Sequential execution policy.
  ///
  /// Continuations are run one after another in order. Each continuation
  /// starts only after the previous one completes.
  static OkPolicy<T> sequence<T>() {
    return SequenceOkPolicy();
  }

  /// Parallel quit-fast policy.
  ///
  /// All continuations are started in parallel. As soon as one of them
  /// terminates on the failure path (else channel for [Cont.both]/[Cont.all],
  /// success channel for [Cont.either]/[Cont.any]), the overall computation
  /// stops immediately without waiting for the others.
  static OkPolicy<T> quitFast<T>() {
    return QuitFastOkPolicy();
  }

  /// Parallel run-all policy.
  ///
  /// All continuations are started in parallel and the computation waits for
  /// all of them to complete before producing a result. When multiple outcomes
  /// of the same kind occur (e.g. multiple successes in [Cont.both]), they are
  /// combined using [combine].
  ///
  /// - [combine]: Function to merge two same-channel outcomes of type [T].
  /// - [shouldFavorCrash]: When `true` and one side crashes while the other
  ///   produces a non-crash outcome, the crash is propagated. When `false`,
  ///   the non-crash outcome is favored.
  static OkPolicy<T> runAll<T>(
    T Function(T t1, T t2) combine, {
    required bool shouldFavorCrash,
  }) {
    return RunAllOkPolicy(
      combine,
      shouldFavorCrash: shouldFavorCrash,
    );
  }
}

/// Sequential execution policy for [Cont.both], [Cont.all], [Cont.either],
/// and [Cont.any].
///
/// Continuations are run one after another in left-to-right order.
/// See [OkPolicy.sequence].
final class SequenceOkPolicy<T> extends OkPolicy<T> {
  const SequenceOkPolicy();
}

/// Parallel quit-fast execution policy for [Cont.both], [Cont.all],
/// [Cont.either], and [Cont.any].
///
/// All continuations run concurrently; the first failure (or first success
/// for `either`/`any`) short-circuits the rest.
/// See [OkPolicy.quitFast].
final class QuitFastOkPolicy<T> extends OkPolicy<T> {
  const QuitFastOkPolicy();
}

/// Parallel run-all execution policy for [Cont.both], [Cont.all],
/// [Cont.either], and [Cont.any].
///
/// All continuations run concurrently and the computation waits for every
/// one to finish. Same-channel outcomes are merged with [combine].
/// See [OkPolicy.runAll].
final class RunAllOkPolicy<T> extends OkPolicy<T> {
  /// Function to merge two same-channel outcome values of type [T].
  final T Function(T t1, T t2) combine;

  /// When `true`, a crash is preferred over a non-crash outcome when one side
  /// crashes and the other succeeds or fails normally.
  final bool shouldFavorCrash;

  const RunAllOkPolicy(
    this.combine, {
    required this.shouldFavorCrash,
  });
}
