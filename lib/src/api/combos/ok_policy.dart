/// Controls how two or more continuations on the success/error channels
/// are executed and how their outcomes are combined.
///
/// Pass an [OkPolicy] to [Cont.both], [Cont.all], [Cont.either], or [Cont.any]
/// via the named `policy` parameter. Use the static factory methods
/// [sequence], [quitFast], or [runAll] to construct a policy.
///
/// Each combinator waits on its own channel and treats the other two as
/// exits: [Cont.both]/[Cont.all] wait for successes and exit on an error
/// or a crash; [Cont.either]/[Cont.any] wait for errors and exit on a
/// success or a crash.
sealed class OkPolicy<T> {
  const OkPolicy();

  /// Sequential execution policy.
  ///
  /// Continuations are run one after another in order. Each continuation
  /// starts only after the previous one ended on the own channel; the first
  /// exit (including a crash) ends the computation.
  ///
  /// The policy carries no data, so it is typed `OkPolicy<Never>`, which fits
  /// any `OkPolicy<T>` and leaves the combinator's types to be inferred from
  /// its continuations.
  static OkPolicy<Never> sequence() {
    return const SequenceOkPolicy._();
  }

  /// Parallel quit-fast policy.
  ///
  /// All continuations are started in parallel. As soon as one of them
  /// exits (else or crash for [Cont.both]/[Cont.all], then or crash for
  /// [Cont.either]/[Cont.any]), the overall computation stops immediately
  /// without waiting for the others, and the others are cancelled.
  /// Collected results keep list order.
  ///
  /// The policy carries no data, so it is typed `OkPolicy<Never>`, which fits
  /// any `OkPolicy<T>` and leaves the combinator's types to be inferred from
  /// its continuations.
  static OkPolicy<Never> quitFast() {
    return const QuitFastOkPolicy._();
  }

  /// Parallel run-all policy.
  ///
  /// All continuations are started in parallel and the computation waits for
  /// all of them to complete before producing a result. If one ends on the
  /// own channel and another exits, the result is the exit. When multiple
  /// exits of the same kind occur (e.g. multiple errors in [Cont.both]),
  /// they are combined using [combine].
  ///
  /// Results are collected in completion order, not list order. Tag each
  /// result (e.g. with a record holding an id) when you need to know which
  /// continuation produced it.
  ///
  /// - [combine]: Function to merge two same-channel outcomes of type [T].
  /// - [shouldFavorCrash]: Decides between two different exits. When `true`
  ///   and one side crashes while another exits on the other channel (else
  ///   for [Cont.both]/[Cont.all], then for [Cont.either]/[Cont.any]), the
  ///   crash is propagated. When `false`, the other exit is favored.
  static OkPolicy<T> runAll<T>(
    T Function(T t1, T t2) combine, {
    required bool shouldFavorCrash,
  }) {
    return RunAllOkPolicy._(
      combine,
      shouldFavorCrash: shouldFavorCrash,
    );
  }
}

/// Sequential execution policy for [Cont.both], [Cont.all], [Cont.either],
/// and [Cont.any].
///
/// Continuations are run one after another in left-to-right order; the
/// next one runs only if the previous one ended on the own channel.
/// See [OkPolicy.sequence].
final class SequenceOkPolicy<T> extends OkPolicy<T> {
  const SequenceOkPolicy._();
}

/// Parallel quit-fast execution policy for [Cont.both], [Cont.all],
/// [Cont.either], and [Cont.any].
///
/// All continuations run concurrently; the first failure (or first success
/// for `either`/`any`) or the first crash short-circuits the rest.
/// See [OkPolicy.quitFast].
final class QuitFastOkPolicy<T> extends OkPolicy<T> {
  const QuitFastOkPolicy._();
}

/// Parallel run-all execution policy for [Cont.both], [Cont.all],
/// [Cont.either], and [Cont.any].
///
/// All continuations run concurrently and the computation waits for every
/// one to finish. Same-channel exits are merged with [combine], in
/// completion order.
/// See [OkPolicy.runAll].
final class RunAllOkPolicy<T> extends OkPolicy<T> {
  /// Function to merge two same-channel outcome values of type [T].
  final T Function(T t1, T t2) combine;

  /// When `true`, a crash is preferred over the other exit (else for
  /// `both`/`all`, then for `either`/`any`) when both occur. It has no
  /// effect when the other outcome is on the own channel: the crash wins.
  final bool shouldFavorCrash;

  const RunAllOkPolicy._(
    this.combine, {
    required this.shouldFavorCrash,
  });
}
