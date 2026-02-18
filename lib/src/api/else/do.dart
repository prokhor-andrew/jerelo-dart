part of '../../cont.dart';

extension ContElseDoExtension<E, F, A> on Cont<E, F, A> {
  /// Provides a fallback continuation in case of termination.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback
  /// also terminates, only the fallback's errors are propagated (the original
  /// errors are discarded).
  ///
  /// To accumulate errors from both attempts, use [elseZip] instead.
  ///
  /// - [f]: Function that receives errors and produces a fallback continuation.
  Cont<E, F, A> elseDo(
    Cont<E, F, A> Function(List<ContError<F>> errors) f,
  ) {
    return _elseDo(this, f);
  }

  /// Provides a zero-argument fallback continuation.
  ///
  /// Similar to [elseDo] but doesn't use the error information.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<E, F, A> elseDo0(Cont<E, F, A> Function() f) {
    return elseDo((_) {
      return f();
    });
  }

  /// Provides a fallback continuation that has access to both errors and environment.
  ///
  /// Similar to [elseDo], but the fallback function receives both the errors
  /// and the environment. This is useful when error recovery needs access to
  /// configuration or context from the environment.
  ///
  /// - [f]: Function that takes the environment and errors, and returns a fallback continuation.
  Cont<E, F, A> elseDoWithEnv(
    Cont<E, F, A> Function(E env, List<ContError<F>> errors)
        f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return elseDo((errors) {
        return f(e, [...errors]);
      });
    });
  }

  /// Provides a fallback continuation with access to the environment only.
  ///
  /// Similar to [elseDoWithEnv], but the fallback function only receives the
  /// environment and ignores the error information. This is useful when error
  /// recovery needs access to configuration but doesn't need to inspect the errors.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  Cont<E, F, A> elseDoWithEnv0(
      Cont<E, F, A> Function(E env) f) {
    return elseDoWithEnv((e, _) {
      return f(e);
    });
  }
}
