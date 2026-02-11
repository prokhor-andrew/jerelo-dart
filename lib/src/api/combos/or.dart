part of '../../cont.dart';

extension ContOrExtension<E, A> on Cont<E, A> {
  /// Instance method for racing this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.either]. Races this continuation
  /// against [right], returning the first successful value.
  ///
  /// - [right]: The other continuation to race with.
  /// - [policy]: Execution policy determining how continuations are run.
  Cont<E, A> or(
    Cont<E, A> right, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    return Cont.either(this, right, policy: policy);
  }
}
