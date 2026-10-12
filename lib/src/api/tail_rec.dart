part of '../cont.dart';

/// One step of [Cont.tailRecM]: continue the loop with a new state, or
/// finish it with a result.
///
/// - [S]: The loop state.
/// - [A]: The result of the loop.
sealed class TailRec<S, A> {
  const TailRec();

  /// Continues the loop with [state].
  static TailRec<S, A> next<S, A>(S state) {
    return NextTailRec._(state);
  }

  /// Finishes the loop with [result].
  static TailRec<S, A> done<S, A>(A result) {
    return DoneTailRec._(result);
  }
}

/// A [TailRec] step that continues the loop with [state].
final class NextTailRec<S, A> extends TailRec<S, A> {
  /// The state for the next iteration.
  final S state;

  const NextTailRec._(this.state);

  @override
  String toString() {
    return 'NextTailRec($state)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! NextTailRec) {
      return false;
    }

    return state == other.state;
  }

  @override
  int get hashCode => Object.hash(NextTailRec, state);
}

/// A [TailRec] step that finishes the loop with [result].
final class DoneTailRec<S, A> extends TailRec<S, A> {
  /// The result of the loop.
  final A result;

  const DoneTailRec._(this.result);

  @override
  String toString() {
    return 'DoneTailRec($result)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! DoneTailRec) {
      return false;
    }

    return result == other.result;
  }

  @override
  int get hashCode => Object.hash(DoneTailRec, result);
}
