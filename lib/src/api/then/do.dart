part of '../../cont.dart';

extension ContThenDoExtension<E, F, A> on Cont<E, F, A> {
  /// Chains a [Cont]-returning function to create dependent computations.
  ///
  /// Monadic bind operation. Sequences continuations where the second depends
  /// on the result of the first. Errors and crashes of this continuation are
  /// passed through, and a throw from [f] becomes a crash. A cancel is
  /// forwarded to whichever of the two continuations is running.
  ///
  /// - [f]: Function that takes a value and returns a continuation.
  Cont<E, F, A2> thenDo<A2>(
    Cont<E, F, A2> Function(A value) f,
  ) {
    return _ThenDoCont<E, F, A, A2>(this, f);
  }
}
