part of '../../cont.dart';

extension ContElseZipExtension<E, F, A> on Cont<E, F, A> {
  /// Attempts a fallback continuation and combines error from both attempts.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback also
  /// terminates, concatenates error from both attempts before terminating.
  ///
  /// Unlike [elseDo], which only keeps the second error list, this method
  /// accumulates and combines error from both attempts.
  ///
  /// - [f]: Function that receives original error and produces a fallback continuation.
  Cont<E, F3, A> elseZip<F2, F3>(
    Cont<E, F2, A> Function(ContError<F>) f,
    ContError<F3> Function(
      ContError<F> f1,
      ContError<F2> f2,
    ) combine,
  ) {
    return _elseZip(this, f, combine);
  }

  /// Zero-argument version of [elseZip].
  ///
  /// Similar to [elseZip] but doesn't use the original error information
  /// when producing the fallback continuation.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<E, F3, A> elseZip0<F2, F3>(
    Cont<E, F2, A> Function() f,
    ContError<F3> Function(
      ContError<F> f1,
      ContError<F2> f2,
    ) combine,
  ) {
    return elseZip((_) {
      return f();
    }, combine);
  }

  /// Attempts a fallback continuation with access to the environment and combines error.
  ///
  /// Similar to [elseZip], but the fallback function receives both the original
  /// error and the environment. If both the original attempt and fallback fail,
  /// their error are concatenated. This is useful when error recovery strategies
  /// need access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and error, and produces a fallback continuation.
  Cont<E, F3, A> elseZipWithEnv<F2, F3>(
    Cont<E, F2, A> Function(E env, ContError<F>) f,
    ContError<F3> Function(
      ContError<F> f1,
      ContError<F2> f2,
    ) combine,
  ) {
    return Cont.ask<E, F3>().thenDo((e) {
      return elseZip((error) {
        return f(e, error);
      }, combine);
    });
  }

  /// Attempts a fallback continuation with access to the environment only and combines error.
  ///
  /// Similar to [elseZipWithEnv], but the fallback function only receives the
  /// environment and ignores the original error information.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  Cont<E, F3, A> elseZipWithEnv0<F2, F3>(
    Cont<E, F2, A> Function(E env) f,
    ContError<F3> Function(
      ContError<F> f1,
      ContError<F2> f2,
    ) combine,
  ) {
    return elseZipWithEnv((e, _) {
      return f(e);
    }, combine);
  }
}
