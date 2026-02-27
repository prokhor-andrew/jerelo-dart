import 'package:jerelo/jerelo.dart';

extension ContCoalesceExtension<E, F, A> on Cont<E, F, A> {
  /// Instance method for coalescing the crash paths of this continuation and [right].
  ///
  /// Convenient instance method wrapper for [Cont.coalesce]. Executes this continuation
  /// and [right] according to the specified [policy], coalescing crashes when both crash.
  ///
  /// - [right]: The other continuation whose crash path is coalesced.
  /// - [policy]: Crash policy determining how crashes are coalesced.
  Cont<E, F, A> coalesceWith(
    Cont<E, F, A> right, {
    required CrashPolicy<F, A> policy,
  }) {
    return Cont.coalesce(this, right, policy: policy);
  }
}
