part of '../../cont.dart';

/// Extension providing flatten operation for nested continuations.
extension ContFlattenExtension<E, F, A>
    on Cont<E, F, Cont<E, F, A>> {
  /// Flattens a nested [Cont] structure.
  ///
  /// Converts [Cont]<[E], [Cont]<[E], [A]>> to [Cont]<[E], [A]>.
  /// Equivalent to `then((contA) => contA)`.
  Cont<E, F, A> flatten() {
    return thenDo((contA) {
      return contA;
    });
  }
}
