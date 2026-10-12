import 'package:jerelo/jerelo.dart';

extension ContElseMapExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms the termination error using a pure function.
  ///
  /// If the continuation terminates, applies the transformation function to
  /// the error value and terminates with the transformed error. This is useful
  /// for enriching or adapting error information.
  ///
  /// - [f]: Function that transforms the error value.
  Cont<E, F2, A> elseMap<F2>(
    F2 Function(F error) f,
  ) {
    return elseDo((error) {
      return Cont.error(f(error));
    });
  }
}
