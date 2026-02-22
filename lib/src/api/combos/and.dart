import 'package:jerelo/jerelo.dart';

extension ContAndExtension<E, F, A> on Cont<E, F, A> {
  /// Instance method for combining this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.both]. Executes this continuation
  /// and [right] according to the specified [policy], then combines their values.
  ///
  /// - [right]: The other continuation to combine with.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  Cont<E, F, A3> and<A2, A3>(
    Cont<E, F, A2> right,
    A3 Function(A a, A2 a2) combine, {
    required OkPolicy<F> policy,
    //
  }) {
    return Cont.both(this, right, combine, policy: policy);
  }

  /// Instance method for combining this continuation with another using crash-channel routing.
  ///
  /// Convenient instance method wrapper for [Cont.bothCrash]. Executes this continuation
  /// and [right] according to the specified [policy], routing panics to [onCrash]
  /// instead of converting them to errors. Requires homogeneous [F] and [A] types.
  ///
  /// - [right]: The other continuation to combine with.
  /// - [policy]: Execution policy determining how continuations run and results are combined.
  Cont<E, F, A> andCrash(
    Cont<E, F, A> right, {
    required CrashPolicy<F, A> policy,
    //
  }) {
    return Cont.bothCrash(this, right, policy: policy);
  }
}
