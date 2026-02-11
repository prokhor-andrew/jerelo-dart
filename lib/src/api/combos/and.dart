part of '../../cont.dart';

extension ContAndExtension<E, A> on Cont<E, A> {
  /// Instance method for combining this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.both]. Executes this continuation
  /// and [right] according to the specified [policy], then combines their values.
  ///
  /// - [right]: The other continuation to combine with.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  Cont<E, A3> and<A2, A3>(
    Cont<E, A2> right,
    A3 Function(A a, A2 a2) combine, {
    required ContBothPolicy policy,
    //
  }) {
    return Cont.both(this, right, combine, policy: policy);
  }
}
