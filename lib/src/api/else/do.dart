import 'package:jerelo/jerelo.dart';

/// Implementation of monadic bind (flatMap) on the termination path.
///
/// Runs [cont], and on termination passes the error to [f] to produce a
/// fallback continuation. If the fallback also terminates, only its error
/// are propagated (the original error are discarded).
Cont<E, F2, A> _elseDo<E, F, F2, A>(
  Cont<E, F, A> cont,
  Cont<E, F2, A> Function(F error) f,
) {
  return Cont.fromRun((runtime, observer) {
    cont.runWith(
      runtime,
      observer.copyUpdateOnElse((error) {
        if (runtime.isCancelled()) {
          return;
        }

        final onCrash = observer.safeRun(() {
          final contA = f(error).absurdify();
          contA.runWith(
            runtime,
            observer.copyUpdateOnElse((error2) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onElse(error2);
            }),
          );
        });

        onCrash?.call();
      }),
    );
  });
}

extension ContElseDoExtension<E, F, A> on Cont<E, F, A> {
  /// Provides a fallback continuation in case of termination.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback
  /// also terminates, only the fallback's error are propagated (the original
  /// error are discarded).
  ///
  /// To accumulate error from both attempts, use [elseZip] instead.
  ///
  /// - [f]: Function that receives error and produces a fallback continuation.
  Cont<E, F2, A> elseDo<F2>(
    Cont<E, F2, A> Function(F error) f,
  ) {
    return _elseDo(this, f);
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
  /// and the environment. This is useful when error recovery needs access to
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
  /// recovery needs access to configuration but doesn't need to inspect the error.
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
