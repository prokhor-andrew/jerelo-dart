import 'package:jerelo/jerelo.dart';

/// Implementation of side-effect execution on the termination path.
///
/// Runs [cont], and on termination executes the side-effect continuation
/// produced by [f]. If the side-effect terminates, the original error are
/// propagated. If the side-effect succeeds, promotion occurs with the
/// side-effect's value.
Cont<E, F, A> _elseTap<E, F, F2, A>(
  Cont<E, F, A> cont,
  Cont<E, F2, A> Function(F error) f,
) {
  return cont.elseDo((error) {
    final Cont<E, F2, A> contA2 = f(error).absurdify();
    return contA2.elseMapTo(error);
  });
}

extension ContElseTapExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on termination.
  ///
  /// If the continuation terminates, executes the side-effect continuation for its effects.
  /// The behavior depends on the side-effect's outcome:
  ///
  /// - If the side-effect terminates: Returns the original error (ignoring side-effect error).
  /// - If the side-effect succeeds: Returns the side-effect's success value, effectively
  ///   promoting from the original termination.
  ///
  /// This means the operation can promote from termination if the side-effect succeeds.
  /// If you want to always propagate the original termination regardless of the side-effect's
  /// outcome, use [elseFork] instead.
  ///
  /// - [f]: Function that receives the original error and returns a side-effect continuation.
  Cont<E, F, A> elseTap<F2>(
    Cont<E, F2, A> Function(F error) f,
  ) {
    return _elseTap(this, f);
  }

  /// Executes a zero-argument side-effect continuation on termination.
  ///
  /// Similar to [elseTap] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> elseTap0<F2>(Cont<E, F2, A> Function() f) {
    return elseTap((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment.
  ///
  /// Similar to [elseTap], but the side-effect function receives both the error
  /// and the environment. This allows error-handling side-effects (like logging or
  /// reporting) to access configuration or context information.
  ///
  /// - [f]: Function that takes the environment and error, and returns a side-effect continuation.
  Cont<E, F, A> elseTapWithEnv<F2>(
    Cont<E, F2, A> Function(E env, F error) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return elseTap((error) {
        return f(e, error);
      });
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment only.
  ///
  /// Similar to [elseTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> elseTapWithEnv0<F2>(
    Cont<E, F2, A> Function(E env) f,
  ) {
    return elseTapWithEnv((e, _) {
      return f(e);
    });
  }
}
