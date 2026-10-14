part of '../cont.dart';

// One step of Cont._tailRecM: continue the loop with a new state, or
// finish it with a result.
sealed class _TailRec<S, A> {
  const _TailRec();
}

final class _NextTailRec<S, A> extends _TailRec<S, A> {
  final S state;

  const _NextTailRec(this.state);
}

final class _DoneTailRec<S, A> extends _TailRec<S, A> {
  final A result;

  const _DoneTailRec(this.result);
}
