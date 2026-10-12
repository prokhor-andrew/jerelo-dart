import 'package:jerelo/jerelo.dart';

extension ContEnvExtension<E, F, A> on Cont<E, F, A> {
  /// Runs this continuation with a transformed environment.
  ///
  /// Transforms the environment from [E2] to [E] using the provided function,
  /// then executes this continuation with the transformed environment.
  /// This allows adapting the continuation to work in a context with a
  /// different environment type.
  ///
  /// - [f]: Function that transforms the outer environment to the inner environment.
  Cont<E2, F, A> local<E2>(E Function(E2) f) {
    return Cont.fromRun((runtime, observer) {
      final env = f(runtime.env());

      runWith(runtime.copyUpdateEnv(env), observer);
    });
  }

  /// Runs [cont] using the success value of this continuation as its environment.
  ///
  /// When this continuation succeeds with value [a], [cont] is executed with [a]
  /// as its environment. Effectively threads the success value into the environment
  /// of the inner continuation.
  ///
  /// - [cont]: A continuation whose environment type matches this continuation's
  ///   success type [A].
  Cont<E, F, A2> thenInject<A2>(Cont<A, F, A2> cont) {
    return thenDo((a) {
      return cont.local((_) {
        return a;
      });
    });
  }

  /// Runs this continuation using the success value of [cont] as its environment.
  ///
  /// Flipped version of [thenInject]: when [cont] succeeds with value [e], this
  /// continuation is executed with [e] as its environment.
  ///
  /// - [cont]: A continuation that produces the environment value for this continuation.
  Cont<E0, F, A> injectedByThen<E0>(Cont<E0, F, E> cont) {
    return cont.thenInject(this);
  }

  /// Runs [cont] using the error value of this continuation as its environment.
  ///
  /// When this continuation terminates on the else channel with error [f], [cont]
  /// is executed with [f] as its environment. Effectively threads the error value
  /// into the environment of the inner continuation.
  ///
  /// - [cont]: A continuation whose environment type matches this continuation's
  ///   error type [F].
  Cont<E, F2, A> elseInject<F2>(Cont<F, F2, A> cont) {
    return elseDo((f) {
      return cont.local((_) {
        return f;
      });
    });
  }

  /// Runs this continuation using the error value of [cont] as its environment.
  ///
  /// Flipped version of [elseInject]: when [cont] terminates on the else channel
  /// with error [e], this continuation is executed with [e] as its environment.
  ///
  /// - [cont]: A continuation whose error type matches this continuation's
  ///   environment type [E].
  Cont<E0, F, A> injectedByElse<E0>(Cont<E0, E, A> cont) {
    return cont.elseInject(this);
  }
}
