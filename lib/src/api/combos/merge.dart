import 'package:jerelo/jerelo.dart';

extension ContMergeExtension<E, F, A> on Cont<E, F, A> {
  Cont<E, F, A> mergeWith(
    Cont<E, F, A> right, {
    required CrashPolicy<F, A> policy,
    //
  }) {
    return Cont.merge(this, right, policy: policy);
  }
}
