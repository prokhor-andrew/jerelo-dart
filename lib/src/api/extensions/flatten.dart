import 'package:jerelo/jerelo.dart';

/// Extension providing flatten operation for nested continuations.
extension ContFlattenExtension<E, F, A>
    on Cont<E, F, Cont<E, F, A>> {
  /// Flattens a nested [Cont] structure.
  ///
  /// Converts [Cont]<[E], [F], [Cont]<[E], [F], [A]>> to
  /// [Cont]<[E], [F], [A]>.
  /// Equivalent to `thenDo((contA) => contA)`.
  Cont<E, F, A> flatten() {
    return thenDo((contA) {
      return contA;
    });
  }
}
