part of '../../cont.dart';

extension ContDecorExtension<E, F, A> on Cont<E, F, A> {
  /// Transforms the execution of the continuation using a natural transformation.
  ///
  /// Applies a function that wraps or modifies the underlying run behavior.
  /// This is useful for intercepting execution to add middleware-like behavior
  /// such as logging, timing, or modifying how observers receive callbacks.
  ///
  /// The transformation function receives both the original run function and
  /// the observer, allowing custom execution behavior to be injected.
  ///
  /// - [f]: A transformation function that receives the run function and observer,
  ///   and implements custom execution logic by calling the run function with the
  ///   observer at the appropriate time.
  ///
  /// Example:
  /// ```dart
  /// // Add logging around execution
  /// final logged = cont.decor((run, runtime, observer) {
  ///   print('Starting execution');
  ///   run(runtime, observer);
  ///   print('Execution initiated');
  /// });
  /// ```
  Cont<E, F, A> decor(
    void Function(
      void Function(ContRuntime<E>, ContObserver<F, A>) run,
      ContRuntime<E> runtime,
      ContObserver<F, A> observer,
      //
    ) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      f(_run, runtime, observer);
    });
  }
}
