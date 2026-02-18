part of '../../cont.dart';

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

      _run(runtime.copyUpdateEnv(env), observer);
    });
  }

  /// Runs this continuation with a new environment from a zero-argument function.
  ///
  /// Similar to [local] but obtains the environment from a zero-argument function
  /// instead of transforming the existing environment.
  ///
  /// - [f]: Zero-argument function that provides the new environment.
  Cont<E2, F, A> local0<E2>(E Function() f) {
    return local((_) {
      return f();
    });
  }

  /// Runs this continuation with a fixed environment value.
  ///
  /// Replaces the environment context with the provided value for the
  /// execution of this continuation. This is useful for providing
  /// configuration, dependencies, or context to a continuation.
  ///
  /// - [value]: The environment value to use.
  Cont<E2, F, A> scope<E2>(E value) {
    return local0(() {
      return value;
    });
  }

  /// Injects the value produced by this continuation as the environment for another continuation.
  ///
  /// This method enables dependency injection patterns where the result of one
  /// continuation becomes the environment (context) for another. It sequences
  /// this continuation with [cont], passing the produced value as [cont]'s environment.
  ///
  /// The transformation changes the environment type from [E] to [A], and the
  /// value type from [A] to [A2]. This is useful when you want to:
  /// - Build a configuration/dependency and run operations with it
  /// - Create resources and inject them into computations that need them
  /// - Chain operations where output becomes context for the next stage
  ///
  /// Type parameters:
  /// - [A2]: The value type produced by the target continuation.
  ///
  /// Parameters:
  /// - [cont]: The continuation that will receive this continuation's value as its environment.
  ///
  /// Returns a continuation that:
  /// 1. Executes this continuation to produce a value of type [A]
  /// 2. Uses that value as the environment for [cont]
  /// 3. Produces [cont]'s result of type [A2]
  ///
  /// Example:
  /// ```dart
  /// // Create a database configuration
  /// final configCont = Cont.of<(), DbConfig>(DbConfig('localhost', 5432));
  ///
  /// // Define an operation that needs the config as environment
  /// final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  ///   return executeQuery(config, 'SELECT * FROM users');
  /// });
  ///
  /// // Inject the config into the query operation
  /// final result = configCont.injectInto(queryOp);
  /// // Type: Cont<(), List<User>>
  /// ```
  Cont<E, F, A2> injectInto<A2>(Cont<A, F, A2> cont) {
    return thenDo((a) {
      Cont<A, F, A2> contA2 = cont;
      if (contA2 is Cont<A, F, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      return contA2.scope(a);
    });
  }

  /// Receives the environment for this continuation from another continuation's value.
  ///
  /// This method is the inverse of [injectInto]. It allows this continuation to
  /// obtain its required environment from the result of another continuation.
  /// The outer continuation [cont] produces a value of type [E] which becomes
  /// the environment for this continuation.
  ///
  /// This is equivalent to `cont.injectInto(this)` but provides a more intuitive
  /// syntax when you want to express that this continuation is being supplied
  /// with dependencies from another source.
  ///
  /// Type parameters:
  /// - [E0]: The environment type of the outer continuation.
  ///
  /// Parameters:
  /// - [cont]: The continuation that produces the environment value this continuation needs.
  ///
  /// Returns a continuation that:
  /// 1. Executes [cont] to produce a value of type [E]
  /// 2. Uses that value as the environment for this continuation
  /// 3. Produces this continuation's result of type [A]
  ///
  /// Example:
  /// ```dart
  /// // Define an operation that needs a database config
  /// final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  ///   return executeQuery(config, 'SELECT * FROM users');
  /// });
  ///
  /// // Create a continuation that produces the config
  /// final configProvider = Cont.of<(), DbConfig>(DbConfig('localhost', 5432));
  ///
  /// // Express that queryOp receives its environment from configProvider
  /// final result = queryOp.injectedBy(configProvider);
  /// // Type: Cont<(), List<User>>
  /// ```
  Cont<E0, F, A> injectedBy<E0>(Cont<E0, F, E> cont) {
    return cont.injectInto(this);
  }
}
