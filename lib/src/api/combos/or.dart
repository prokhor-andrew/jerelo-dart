import 'package:jerelo/jerelo.dart';

extension ContOrExtension<E, F, A> on Cont<E, F, A> {
  /// Instance method for racing this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.either]. Races this continuation
  /// against [right], returning the first successful value.
  ///
  /// - [right]: The other continuation to race with.
  /// - [policy]: Execution policy determining how continuations are run.
  Cont<E, F3, A> or<F2, F3>(
    Cont<E, F2, A> right,
    F3 Function(F, F2) combine, {
    required OkPolicy<A> policy,
    //
  }) {
    return Cont.either(
      this,
      right,
      combine,
      policy: policy,
    );
  }
}
