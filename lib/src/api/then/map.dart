import 'package:jerelo/jerelo.dart';

extension ContThenMapExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms the value inside a [Cont] using a pure function.
  ///
  /// Applies a function to the successful value of the continuation without
  /// affecting the termination case.
  ///
  /// - [f]: Transformation function to apply to the value.
  Cont<E, F, A2> thenMap<A2>(A2 Function(A value) f) {
    return thenDo((a) {
      final a2 = f(a);
      return Cont.of(a2);
    });
  }
}
