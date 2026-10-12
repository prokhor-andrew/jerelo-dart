part of '../cont.dart';

/// One step of [Cont.tailRecM]: continue the loop with a new state, or
/// finish it with a result.
///
/// - [S]: The loop state.
/// - [A]: The result of the loop.
sealed class TailRec<S, A> {
  const TailRec();

  /// Continues the loop with [state].
  const factory TailRec.next(S state) = TailRecNext<S, A>;

  /// Finishes the loop with [result].
  const factory TailRec.done(A result) = TailRecDone<S, A>;
}

/// A [TailRec] step that continues the loop with [state].
final class TailRecNext<S, A> extends TailRec<S, A> {
  /// The state for the next iteration.
  final S state;

  const TailRecNext(this.state);

  @override
  String toString() {
    return 'TailRec.next($state)';
  }
}

/// A [TailRec] step that finishes the loop with [result].
final class TailRecDone<S, A> extends TailRec<S, A> {
  /// The result of the loop.
  final A result;

  const TailRecDone(this.result);

  @override
  String toString() {
    return 'TailRec.done($result)';
  }
}
