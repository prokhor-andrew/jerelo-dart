import 'package:jerelo/jerelo.dart';

extension ContDecorExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms the execution of the continuation using a natural transformation.
  ///
  /// Applies a function that wraps or modifies the underlying run behavior.
  /// This is useful for intercepting execution to add middleware-like behavior
  /// such as logging, timing, or modifying how observers receive callbacks.
  ///
  /// The transformation function receives the original run function, the
  /// environment and the observer, allowing custom execution behavior to be
  /// injected. A throw from it becomes a crash, or a panic if the
  /// computation has already reported. Avoid throwing after calling the
  /// run function: the computation it started keeps running, and since
  /// its canceller is lost, it can no longer be cancelled. Return the
  /// run function's canceller instead.
  ///
  /// - [f]: A transformation function that receives the run function, the
  ///   environment and the observer, and implements custom execution logic
  ///   by calling the run function with the environment and observer at the
  ///   appropriate time. It returns the
  ///   canceller of the run it started, which is usually the value the run
  ///   function returned; a cancel is forwarded to it.
  ///
  /// Example:
  /// ```dart
  /// // Add logging around execution
  /// final logged = cont.decorate((run, env, observer) {
  ///   print('Starting execution');
  ///   final cancel = run(env, observer);
  ///   print('Execution initiated');
  ///   return cancel;
  /// });
  /// ```
  Cont<E, F, A> decorate(
    void Function() Function(
      void Function() Function(E, ContObserver<F, A>) run,
      E env,
      ContObserver<F, A> observer,
      //
    ) f,
  ) {
    return Cont.fromRun((env, observer) {
      return f(runWith, env, observer);
    });
  }
}
