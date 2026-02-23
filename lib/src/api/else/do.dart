import 'package:jerelo/jerelo.dart';

extension ContElseDoExtension<E, F, A> on Cont<E, F, A> {
  /// Provides a fallback continuation in case of termination.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback
  /// also terminates, only the fallback's error is propagated (the original
  /// error is discarded).
  ///
  /// To accumulate errors from both attempts, use [elseZip] instead.
  ///
  /// - [f]: Function that receives error and produces a fallback continuation.
  Cont<E, F2, A> elseDo<F2>(
    Cont<E, F2, A> Function(F error) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      runWith(
        runtime,
        observer.copyUpdateOnElse((error) {
          if (runtime.isCancelled()) {
            return;
          }

          final crash = ContCrash.tryCatch(() {
            final contA = f(error).absurdify();
            contA.runWith(runtime, observer);
          });

          if (crash != null) {
            observer.onCrash(crash);
          }
        }),
      );
    });
  }

  /// Provides a zero-argument fallback continuation.
  ///
  /// Similar to [elseDo] but doesn't use the error information.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<E, F2, A> elseDo0<F2>(Cont<E, F2, A> Function() f) {
    return elseDo((_) {
      return f();
    });
  }

  /// Provides a fallback continuation that has access to both error and environment.
  ///
  /// Similar to [elseDo], but the fallback function receives both the error
  /// and the environment. This is useful when error handling needs access to
  /// configuration or context from the environment.
  ///
  /// - [f]: Function that takes the environment and error, and returns a fallback continuation.
  Cont<E, F2, A> elseDoWithEnv<F2>(
    Cont<E, F2, A> Function(E env, F error) f,
  ) {
    return Cont.askThen<E, F2>().thenDo((e) {
      return elseDo((error) {
        return f(e, error);
      });
    });
  }

  /// Provides a fallback continuation with access to the environment only.
  ///
  /// Similar to [elseDoWithEnv], but the fallback function only receives the
  /// environment and ignores the error information. This is useful when error
  /// handling needs access to configuration but doesn't need to inspect the error.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  Cont<E, F2, A> elseDoWithEnv0<F2>(
    Cont<E, F2, A> Function(E env) f,
  ) {
    return elseDoWithEnv((e, _) {
      return f(e);
    });
  }
}
