import 'package:jerelo/jerelo.dart';

extension ContMergeExtension<E, F, A> on Cont<E, F, A> {
  /// Instance method for merging the crash paths of this continuation and [right].
  ///
  /// Convenient instance method wrapper for [Cont.merge]. Executes this continuation
  /// and [right] according to the specified [policy], merging crashes when both crash.
  ///
  /// - [right]: The other continuation whose crash path is merged.
  /// - [policy]: Crash policy determining how crashes are merged.
  Cont<E, F, A> mergeWith(
    Cont<E, F, A> right, {
    required CrashPolicy<F, A> policy,
  }) {
    return Cont.merge(this, right, policy: policy);
  }
}
