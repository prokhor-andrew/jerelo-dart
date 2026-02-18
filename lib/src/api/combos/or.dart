part of '../../cont.dart';

extension ContOrExtension<E, F, A> on Cont<E, F, A> {
  /// Instance method for racing this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.either]. Races this continuation
  /// against [right], returning the first successful value.
  ///
  /// - [right]: The other continuation to race with.
  /// - [policy]: Execution policy determining how continuations are run.
  Cont<E, F, A> or(
    Cont<E, F, A> right, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    return Cont.either(this, right, policy: policy);
  }
}
