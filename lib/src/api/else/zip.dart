part of '../../cont.dart';

extension ContElseZipExtension<E, F, A> on Cont<E, F, A> {
  /// Attempts a fallback continuation and combines errors from both attempts.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback also
  /// terminates, concatenates errors from both attempts before terminating.
  ///
  /// Unlike [elseDo], which only keeps the second error list, this method
  /// accumulates and combines errors from both attempts.
  ///
  /// - [f]: Function that receives original errors and produces a fallback continuation.
  Cont<E, F, A> elseZip(
    Cont<E, F, A> Function(List<ContError<F>>) f,
  ) {
    return _elseZip(this, f);
  }

  /// Zero-argument version of [elseZip].
  ///
  /// Similar to [elseZip] but doesn't use the original error information
  /// when producing the fallback continuation.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<E, F, A> elseZip0(Cont<E, F, A> Function() f) {
    return elseZip((_) {
      return f();
    });
  }

  /// Attempts a fallback continuation with access to the environment and combines errors.
  ///
  /// Similar to [elseZip], but the fallback function receives both the original
  /// errors and the environment. If both the original attempt and fallback fail,
  /// their errors are concatenated. This is useful when error recovery strategies
  /// need access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and errors, and produces a fallback continuation.
  Cont<E, F, A> elseZipWithEnv(
    Cont<E, F, A> Function(E env, List<ContError<F>>) f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return elseZip((errors) {
        return f(e, [...errors]);
      });
    });
  }

  /// Attempts a fallback continuation with access to the environment only and combines errors.
  ///
  /// Similar to [elseZipWithEnv], but the fallback function only receives the
  /// environment and ignores the original error information.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  Cont<E, F, A> elseZipWithEnv0(
      Cont<E, F, A> Function(E env) f) {
    return elseZipWithEnv((e, _) {
      return f(e);
    });
  }
}
