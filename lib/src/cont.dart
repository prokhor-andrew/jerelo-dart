import 'package:jerelo/jerelo.dart';

part 'helper/either.dart';
part 'helper/stack_safe_loop_policy.dart';
part 'helper/both_helpers.dart';
part 'helper/either_helpers.dart';
part 'cont_observer.dart';
part 'cont_runtime.dart';

/// A continuation monad representing a computation that will eventually
/// produce a value of type [A] or terminate with errors.
///
/// [Cont] provides a powerful abstraction for managing asynchronous operations,
/// error handling, and composition of effectful computations. It follows the
/// continuation-passing style where computations are represented as functions
/// that take callbacks for success and failure.
///
/// Type parameters:
/// - [E]: The environment type providing context for the continuation execution.
/// - [A]: The value type that the continuation produces upon success.
final class Cont<E, A> {
  final void Function(
    ContRuntime<E> runtime,
    ContObserver<A> observer,
  )
  _run;

  /// Executes the continuation with separate callbacks for termination and value.
  ///
  /// Initiates execution of the continuation with separate handlers for success
  /// and failure cases.
  ///
  /// - [env]: The environment value to provide as context during execution.
  /// - [onTerminate]: Callback invoked when the continuation terminates with errors.
  /// - [onValue]: Callback invoked when the continuation produces a successful value.
  void run(
    E env,
    void Function(List<ContError> errors) onTerminate,
    void Function(A value) onValue,
  ) {
    _run(
      ContRuntime._(env, () {
        return false;
      }),
      ContObserver._(onTerminate, onValue),
    );
  }

  /// Executes the continuation in a fire-and-forget manner.
  ///
  /// Runs the continuation without waiting for the result. Both success and
  /// failure outcomes are ignored. This is useful for side-effects that should
  /// run asynchronously without blocking or requiring error handling.
  ///
  /// - [env]: The environment value to provide as context during execution.
  void ff(E env) {
    _run(
      ContRuntime._(env, () {
        return false;
      }),
      ContObserver._((_) {}, (_) {}),
    );
  }

  const Cont._(this._run);

  /// Creates a [Cont] from a run function that accepts an observer.
  ///
  /// Constructs a continuation with guaranteed idempotence and exception catching.
  /// The run function receives an observer with `onValue` and `onTerminate` callbacks.
  /// The callbacks should be called as the last instruction in the run function
  /// or saved to be called later.
  ///
  /// - [run]: Function that executes the continuation and calls observer callbacks.
  static Cont<E, A> fromRun<E, A>(
    void Function(
      ContRuntime<E> runtime,
      ContObserver<A> observer,
    )
    run,
  ) {
    return Cont._((runtime, observer) {
      if (runtime.isCancelled()) {
        return;
      }

      if (observer is ContObserver<Never>) {
        observer = ContObserver<A>._(
          observer.onTerminate,
          (_) {},
        );
      }

      bool isDone = false;

      void guardedTerminate(List<ContError> errors) {
        errors = errors.toList(); // defensive copy
        if (runtime.isCancelled()) {
          return;
        }

        if (isDone) {
          return;
        }
        isDone = true;
        observer.onTerminate(errors);
      }

      void guardedValue(A a) {
        if (runtime.isCancelled()) {
          return;
        }

        if (isDone) {
          return;
        }
        isDone = true;
        observer.onValue(a);
      }

      try {
        run(
          runtime,
          ContObserver._(guardedTerminate, guardedValue),
        );
      } catch (error, st) {
        guardedTerminate([ContError(error, st)]);
      }
    });
  }

  /// Creates a [Cont] from a deferred continuation computation.
  ///
  /// Lazily evaluates a continuation-returning function. The inner [Cont] is
  /// not created until the outer one is executed.
  ///
  /// - [thunk]: Function that returns a [Cont] when called.
  static Cont<E, A> fromDeferred<E, A>(
    Cont<E, A> Function() thunk,
  ) {
    return Cont.fromRun((runtime, observer) {
      Cont<E, A> contA = thunk();
      if (contA is Cont<E, Never>) {
        contA = contA.absurd<A>();
      }
      contA._run(runtime, observer);
    });
  }

  /// Creates a [Cont] that immediately succeeds with a value.
  ///
  /// Identity operation that wraps a pure value in a continuation context.
  ///
  /// - [value]: The value to wrap.
  static Cont<E, A> of<E, A>(A value) {
    return Cont.fromRun((runtime, observer) {
      observer.onValue(value);
    });
  }

  /// Creates a [Cont] that immediately terminates with optional errors.
  ///
  /// Creates a continuation that terminates without producing a value.
  /// Used to represent failure states.
  ///
  /// - [errors]: List of errors to terminate with. Defaults to an empty list.
  static Cont<E, A> terminate<E, A>([
    List<ContError> errors = const [],
  ]) {
    errors = errors.toList();
    return Cont.fromRun((runtime, observer) {
      errors = errors
          .toList(); // if same computation ran twice, and got list modified, it won't affect the other one
      observer.onTerminate(errors);
    });
  }

  /// Retrieves the current environment value.
  ///
  /// Accesses the environment of type [E] from the runtime context.
  /// This is used to read configuration, dependencies, or any contextual
  /// information that flows through the continuation execution.
  ///
  /// Returns a continuation that succeeds with the environment value.
  static Cont<E, E> ask<E>() {
    return Cont.fromRun((runtime, observer) {
      observer.onValue(runtime.env());
    });
  }

  /// Transforms the value inside a [Cont] using a pure function.
  ///
  /// Applies a function to the successful value of the continuation without
  /// affecting the termination case.
  ///
  /// - [f]: Transformation function to apply to the value.
  Cont<E, A2> map<A2>(A2 Function(A value) f) {
    return thenDo((a) {
      final a2 = f(a);
      return Cont.of(a2);
    });
  }

  /// Transforms the value inside a [Cont] using a zero-argument function.
  ///
  /// Similar to [map] but ignores the current value and computes a new one.
  ///
  /// - [f]: Zero-argument transformation function.
  Cont<E, A2> map0<A2>(A2 Function() f) {
    return map((_) {
      return f();
    });
  }

  /// Replaces the value inside a [Cont] with a constant.
  ///
  /// Discards the current value and replaces it with a fixed value.
  ///
  /// - [value]: The constant value to replace with.
  Cont<E, A2> as<A2>(A2 value) {
    return map0(() {
      return value;
    });
  }

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
  /// final logged = cont.hoist((run, runtime, observer) {
  ///   print('Starting execution');
  ///   run(runtime, observer);
  ///   print('Execution initiated');
  /// });
  /// ```
  Cont<E, A> hoist(
    void Function(
      void Function(ContRuntime<E>, ContObserver<A>) run,
      ContRuntime<E> runtime,
      ContObserver<A> observer,
      //
    )
    f,
  ) {
    return Cont.fromRun((runtime, observer) {
      f(_run, runtime, observer);
    });
  }

  /// Chains a [Cont]-returning function to create dependent computations.
  ///
  /// Monadic bind operation. Sequences continuations where the second depends
  /// on the result of the first.
  ///
  /// - [f]: Function that takes a value and returns a continuation.
  Cont<E, A2> thenDo<A2>(Cont<E, A2> Function(A value) f) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnValue((a) {
          if (runtime.isCancelled()) {
            return;
          }
          try {
            Cont<E, A2> contA2 = f(a);
            if (contA2 is Cont<E, Never>) {
              contA2 = contA2.absurd<A2>();
            }
            contA2._run(runtime, observer);
          } catch (error, st) {
            observer.onTerminate([ContError(error, st)]);
          }
        }),
      );
    });
  }

  /// Chains a [Cont]-returning zero-argument function.
  ///
  /// Similar to [thenDo] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a continuation.
  Cont<E, A2> thenDo0<A2>(Cont<E, A2> Function() f) {
    return thenDo((_) {
      return f();
    });
  }

  /// Chains a side-effect continuation while preserving the original value.
  ///
  /// Executes a continuation for its side effects, then returns the original value.
  ///
  /// - [f]: Side-effect function that returns a continuation.
  Cont<E, A> thenTap<A2>(Cont<E, A2> Function(A value) f) {
    return thenDo((a) {
      Cont<E, A2> contA2 = f(a);
      if (contA2 is Cont<E, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      return contA2.as(a);
    });
  }

  /// Chains a zero-argument side-effect continuation.
  ///
  /// Similar to [thenTap] but with a zero-argument function.
  ///
  /// - [f]: Zero-argument side-effect function.
  Cont<E, A> thenTap0<A2>(Cont<E, A2> Function() f) {
    return thenTap((_) {
      return f();
    });
  }

  /// Chains and combines two continuation values.
  ///
  /// Sequences two continuations and combines their results using the provided function.
  ///
  /// - [f]: Function to produce the second continuation from the first value.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, A3> thenZip<A2, A3>(
    Cont<E, A2> Function(A value) f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return thenDo((a1) {
      Cont<E, A2> contA2 = f(a1);
      if (contA2 is Cont<E, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      return contA2.map((a2) {
        return combine(a1, a2);
      });
    });
  }

  /// Chains and combines with a zero-argument function.
  ///
  /// Similar to [thenZip] but the second continuation doesn't depend
  /// on the first value.
  ///
  /// - [f]: Zero-argument function to produce the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, A3> thenZip0<A2, A3>(
    Cont<E, A2> Function() f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return thenZip((_) {
      return f();
    }, combine);
  }

  /// Executes a side-effect continuation in a fire-and-forget manner.
  ///
  /// Unlike [thenTap], this method does not wait for the side-effect to complete.
  /// The side-effect continuation is started immediately, and the original value
  /// is returned without delay. Any errors from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the current value and returns a side-effect continuation.
  Cont<E, A> thenFork<A2>(Cont<E, A2> Function(A a) f) {
    return thenDoWithEnv((e, a) {
      // this should not be inside try-catch block
      Cont<E, A2> contA2 = f(a);

      if (contA2 is Cont<E, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      try {
        contA2.ff(e);
      } catch (_) {
        // do nothing, if anything happens to side-effect, it's not
        // a concern of the thenFork
      }

      return Cont.of(a);
    });
  }

  /// Executes a zero-argument side-effect continuation in a fire-and-forget manner.
  ///
  /// Similar to [thenFork] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, A> thenFork0<A2>(Cont<E, A2> Function() f) {
    return thenFork((_) {
      return f();
    });
  }

  /// Provides a fallback continuation in case of termination.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback
  /// also terminates, only the fallback's errors are propagated (the original
  /// errors are discarded).
  ///
  /// To accumulate errors from both attempts, use [elseZip] instead.
  ///
  /// - [f]: Function that receives errors and produces a fallback continuation.
  Cont<E, A> elseDo(
    Cont<E, A> Function(List<ContError> errors) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnTerminate((errors) {
          if (runtime.isCancelled()) {
            return;
          }
          errors = errors.toList(); // defensive copy
          try {
            Cont<E, A> contA = f(errors);

            if (contA is Cont<E, Never>) {
              contA = contA.absurd<A>();
            }

            contA._run(
              runtime,
              observer.copyUpdateOnTerminate((errors2) {
                if (runtime.isCancelled()) {
                  return;
                }
                observer.onTerminate([...errors2]);
              }),
            );
          } catch (error, st) {
            observer.onTerminate([
              ContError(error, st),
            ]); // we return latest error
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
  Cont<E, A> elseDo0(Cont<E, A> Function() f) {
    return elseDo((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on termination.
  ///
  /// If the continuation terminates, executes the side-effect continuation for its effects.
  /// The behavior depends on the side-effect's outcome:
  ///
  /// - If the side-effect terminates: Returns the original errors (ignoring side-effect errors).
  /// - If the side-effect succeeds: Returns the side-effect's success value, effectively
  ///   recovering from the original termination.
  ///
  /// This means the operation can recover from termination if the side-effect succeeds.
  /// If you want to always propagate the original termination regardless of the side-effect's
  /// outcome, use [elseFork] instead.
  ///
  /// - [f]: Function that receives the original errors and returns a side-effect continuation.
  Cont<E, A> elseTap(
    Cont<E, A> Function(List<ContError> errors) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnTerminate((errors) {
          if (runtime.isCancelled()) {
            return;
          }
          errors = errors.toList(); // defensive copy
          try {
            // another defensive copy
            // we need it in case somebody mutates errors inside "f"
            // and then crashes it. In that case we'd go to catch block below,
            // and "errors" there would be different now, which should not happen
            Cont<E, A> contA = f(errors.toList());

            if (contA is Cont<E, Never>) {
              contA = contA.absurd<A>();
            }

            contA._run(
              runtime,
              observer.copyUpdateOnTerminate((_) {
                if (runtime.isCancelled()) {
                  return;
                }
                observer.onTerminate(errors);
              }),
            );
          } catch (_) {
            // we return original errors
            observer.onTerminate(errors);
          }
        }),
      );
    });
  }

  /// Executes a zero-argument side-effect continuation on termination.
  ///
  /// Similar to [elseTap] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, A> elseTap0(Cont<E, A> Function() f) {
    return elseTap((_) {
      return f();
    });
  }

  /// Attempts a fallback continuation and combines errors from both attempts.
  ///
  /// If the continuation terminates, executes the fallback. If the fallback also
  /// terminates, concatenates errors from both attempts before terminating.
  ///
  /// Unlike [elseDo], which only keeps the second error list, this method
  /// accumulates and combines errors from both attempts.
  ///
  /// - [f]: Function that receives original errors and produces a fallback continuation.
  Cont<E, A> elseZip(
    Cont<E, A> Function(List<ContError>) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnTerminate((errors) {
          if (runtime.isCancelled()) {
            return;
          }
          errors = errors.toList(); // defensive copy
          try {
            // another defensive copy
            // we need it in case somebody mutates errors inside "f"
            // and then crashes it. In that case we'd go to catch block below,
            // and "errors" there would be different now, which should not happen
            Cont<E, A> contA = f(errors.toList());
            if (contA is Cont<E, Never>) {
              contA = contA.absurd<A>();
            }
            contA._run(
              runtime,
              observer.copyUpdateOnTerminate((errors2) {
                if (runtime.isCancelled()) {
                  return;
                }
                errors2 = errors2
                    .toList(); // defensive copy
                final combinedErrors = errors + errors2;
                observer.onTerminate(combinedErrors);
              }),
            );
          } catch (error, st) {
            final combinedErrors =
                errors + [ContError(error, st)];
            observer.onTerminate(combinedErrors);
          }
        }),
      );
    });
  }

  /// Zero-argument version of [elseZip].
  ///
  /// Similar to [elseZip] but doesn't use the original error information
  /// when producing the fallback continuation.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<E, A> elseZip0(Cont<E, A> Function() f) {
    return elseZip((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// If the continuation terminates, starts the side-effect continuation without waiting
  /// for it to complete. Unlike [elseTap], this does not wait for the side-effect to
  /// finish before propagating the termination. Any errors from the side-effect are
  /// silently ignored.
  ///
  /// - [f]: Function that returns a side-effect continuation.
  Cont<E, A> elseFork<A2>(
    Cont<E, A2> Function(List<ContError> errors) f,
  ) {
    return elseDoWithEnv((e, errors) {
      // this should not be inside try-catch block
      Cont<E, A2> contA2 = f([...errors]);
      if (contA2 is Cont<E, Never>) {
        contA2 = contA2.absurd<A2>();
      }
      try {
        contA2.ff(e);
      } catch (_) {
        // do nothing, if anything happens to side-effect, it's not
        // a concern of the orElseFork
      }
      return Cont.terminate<E, A>([...errors]);
    });
  }

  /// Executes a zero-argument side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// Similar to [elseFork] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, A> elseFork0<A2>(Cont<E, A2> Function() f) {
    return elseFork((_) {
      return f();
    });
  }

  /// Runs this continuation with a transformed environment.
  ///
  /// Transforms the environment from [E2] to [E] using the provided function,
  /// then executes this continuation with the transformed environment.
  /// This allows adapting the continuation to work in a context with a
  /// different environment type.
  ///
  /// - [f]: Function that transforms the outer environment to the inner environment.
  Cont<E2, A> local<E2>(E Function(E2) f) {
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
  Cont<E2, A> local0<E2>(E Function() f) {
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
  Cont<E2, A> scope<E2>(E value) {
    return local0(() {
      return value;
    });
  }

  /// Chains a continuation-returning function that has access to both the value and environment.
  ///
  /// Similar to [thenDo], but the function receives both the current value and the
  /// environment. This is useful when the next computation needs access to
  /// configuration or context from the environment.
  ///
  /// - [f]: Function that takes the environment and value, and returns a continuation.
  Cont<E, A2> thenDoWithEnv<A2>(
    Cont<E, A2> Function(E env, A a) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenDo((a) {
        return f(e, a);
      });
    });
  }

  /// Chains a continuation-returning function with access to the environment only.
  ///
  /// Similar to [thenDoWithEnv], but the function only receives the environment
  /// and ignores the current value. This is useful when the next computation needs
  /// access to configuration or context but doesn't depend on the previous value.
  ///
  /// - [f]: Function that takes the environment and returns a continuation.
  Cont<E, A2> thenDoWithEnv0<A2>(
    Cont<E, A2> Function(E env) f,
  ) {
    return thenDoWithEnv((e, _) {
      return f(e);
    });
  }

  /// Chains a side-effect continuation with access to both the environment and value.
  ///
  /// Similar to [thenTap], but the side-effect function receives both the current
  /// value and the environment. After executing the side-effect, returns the original
  /// value. This is useful for logging, monitoring, or other side-effects that need
  /// access to both the value and configuration context.
  ///
  /// - [f]: Function that takes the environment and value, and returns a side-effect continuation.
  Cont<E, A> thenTapWithEnv<A2>(
    Cont<E, A2> Function(E env, A a) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenTap((a) {
        return f(e, a);
      });
    });
  }

  /// Chains a side-effect continuation with access to the environment only.
  ///
  /// Similar to [thenTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the current value. After executing the side-effect,
  /// returns the original value.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, A> thenTapWithEnv0<A2>(
    Cont<E, A2> Function(E env) f,
  ) {
    return thenTapWithEnv((e, _) {
      return f(e);
    });
  }

  /// Chains and combines two continuations with access to the environment.
  ///
  /// Similar to [thenZip], but the function producing the second continuation
  /// receives both the current value and the environment. This is useful when
  /// the second computation needs access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and value, and produces the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, A3> thenZipWithEnv<A2, A3>(
    Cont<E, A2> Function(E env, A value) f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenZip((a1) {
        return f(e, a1);
      }, combine);
    });
  }

  /// Chains and combines with a continuation that has access to the environment only.
  ///
  /// Similar to [thenZipWithEnv], but the function producing the second continuation
  /// only receives the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and produces the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<E, A3> thenZipWithEnv0<A2, A3>(
    Cont<E, A2> Function(E env) f,
    A3 Function(A a1, A2 a2) combine,
  ) {
    return thenZipWithEnv((e, _) {
      return f(e);
    }, combine);
  }

  /// Executes a side-effect continuation in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [thenFork], but the side-effect function receives both the current
  /// value and the environment. The side-effect is started immediately without waiting,
  /// and any errors are silently ignored.
  ///
  /// - [f]: Function that takes the environment and value, and returns a side-effect continuation.
  Cont<E, A> thenForkWithEnv<A2>(
    Cont<E, A2> Function(E env, A a) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenFork((a) {
        return f(e, a);
      });
    });
  }

  /// Executes a side-effect continuation in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [thenForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, A> thenForkWithEnv0<A2>(
    Cont<E, A2> Function(E env) f,
  ) {
    return thenForkWithEnv((e, _) {
      return f(e);
    });
  }

  /// Provides a fallback continuation that has access to both errors and environment.
  ///
  /// Similar to [elseDo], but the fallback function receives both the errors
  /// and the environment. This is useful when error recovery needs access to
  /// configuration or context from the environment.
  ///
  /// - [f]: Function that takes the environment and errors, and returns a fallback continuation.
  Cont<E, A> elseDoWithEnv(
    Cont<E, A> Function(E env, List<ContError> errors) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
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
  Cont<E, A> elseDoWithEnv0(Cont<E, A> Function(E env) f) {
    return elseDoWithEnv((e, _) {
      return f(e);
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment.
  ///
  /// Similar to [elseTap], but the side-effect function receives both the errors
  /// and the environment. This allows error-handling side-effects (like logging or
  /// reporting) to access configuration or context information.
  ///
  /// - [f]: Function that takes the environment and errors, and returns a side-effect continuation.
  Cont<E, A> elseTapWithEnv(
    Cont<E, A> Function(E env, List<ContError> errors) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseTap((errors) {
        return f(e, [...errors]);
      });
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment only.
  ///
  /// Similar to [elseTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, A> elseTapWithEnv0(Cont<E, A> Function(E env) f) {
    return elseTapWithEnv((e, _) {
      return f(e);
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
  Cont<E, A> elseZipWithEnv(
    Cont<E, A> Function(E env, List<ContError>) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
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
  Cont<E, A> elseZipWithEnv0(Cont<E, A> Function(E env) f) {
    return elseZipWithEnv((e, _) {
      return f(e);
    });
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [elseFork], but the side-effect function receives both the errors
  /// and the environment. The side-effect is started without waiting for it to complete,
  /// and any errors from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the environment and errors, and returns a side-effect continuation.
  Cont<E, A> elseForkWithEnv(
    Cont<E, A> Function(E env, List<ContError> errors) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseFork((errors) {
        return f(e, [...errors]);
      });
    });
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [elseForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, A> elseForkWithEnv0(
    Cont<E, A> Function(E env) f,
  ) {
    return elseForkWithEnv((e, _) {
      return f(e);
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
  Cont<E, A2> injectInto<A2>(Cont<A, A2> cont) {
    return thenDo((a) {
      Cont<A, A2> contA2 = cont;
      if (contA2 is Cont<A, Never>) {
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
  Cont<E0, A> injectedBy<E0>(Cont<E0, E> cont) {
    return cont.injectInto(this);
  }

  /// Runs two continuations and combines their results according to the specified policy.
  ///
  /// Executes both continuations. Both must succeed for the result to be successful;
  /// if either fails, the entire operation fails. When both succeed, their values
  /// are combined using [combine].
  ///
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [BothSequencePolicy]: Runs [left] then [right] sequentially.
  /// - [BothMergeWhenAllPolicy]: Runs both in parallel, waits for both to complete,
  ///   and merges errors if both fail.
  /// - [BothQuitFastPolicy]: Runs both in parallel, terminates immediately if either fails.
  ///
  /// - [left]: First continuation to execute.
  /// - [right]: Second continuation to execute.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, A3> both<E, A1, A2, A3>(
    Cont<E, A1> left,
    Cont<E, A2> right,
    A3 Function(A1 a, A2 a2) combine, {
    required ContBothPolicy policy,
    //
  }) {
    if (left is Cont<E, Never>) {
      left = left.absurd<A1>();
    }

    if (right is Cont<E, Never>) {
      right = right.absurd<A2>();
    }

    switch (policy) {
      case BothSequencePolicy():
        return left.thenDo((a) {
          return right.map((a2) {
            return combine(a, a2);
          });
        });
      case BothMergeWhenAllPolicy():
        return _bothMergeWhenAll(left, right, combine);
      case BothQuitFastPolicy():
        return _bothQuitFast(left, right, combine);
    }
  }

  /// Instance method for combining this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.both]. Executes this continuation
  /// and [right] according to the specified [policy], then combines their values.
  ///
  /// - [right]: The other continuation to combine with.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  Cont<E, A3> and<A2, A3>(
    Cont<E, A2> right,
    A3 Function(A a, A2 a2) combine, {
    required ContBothPolicy policy,
    //
  }) {
    return Cont.both(this, right, combine, policy: policy);
  }

  /// Runs multiple continuations and collects all results according to the specified policy.
  ///
  /// Executes all continuations in [list] and collects their values into a list.
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [BothSequencePolicy]: Runs continuations one by one in order, stops at first failure.
  /// - [BothMergeWhenAllPolicy]: Runs all in parallel, waits for all to complete,
  ///   and merges errors if any fail.
  /// - [BothQuitFastPolicy]: Runs all in parallel, terminates immediately on first failure.
  ///
  /// - [list]: List of continuations to execute.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, List<A>> all<E, A>(
    List<Cont<E, A>> list, {
    required ContBothPolicy policy,
    //
  }) {
    list = list.toList(); // defensive copy
    switch (policy) {
      case BothSequencePolicy():
        return Cont.fromRun((runtime, observer) {
          list = list.toList(); // defensive copy
          _stackSafeLoop<
            _Either<(int, List<A>), List<ContError>?>,
            (int, List<A>),
            _Either<(), _Either<List<A>, List<ContError>>>
          >(
            seed: _Left((0, [])),
            keepRunningIf: (state) {
              switch (state) {
                case _Left(value: final value):
                  final (index, results) = value;
                  if (index >= list.length) {
                    return _StackSafeLoopPolicyStop(
                      _Right(_Left(results)),
                    );
                  }
                  return _StackSafeLoopPolicyKeepRunning((
                    index,
                    results,
                  ));
                case _Right(value: final value):
                  if (value != null) {
                    return _StackSafeLoopPolicyStop(
                      _Right(_Right(value)),
                    );
                  } else {
                    return _StackSafeLoopPolicyStop(
                      _Left(()),
                    );
                  }
              }
            },
            computation: (tuple, callback) {
              final (i, values) = tuple;
              Cont<E, A> cont = list[i];
              if (cont is Cont<E, Never>) {
                cont = cont.absurd<A>();
              }
              try {
                cont._run(
                  runtime,
                  ContObserver._(
                    (errors) {
                      if (runtime.isCancelled()) {
                        callback(_Right(null));
                        return;
                      }
                      callback(_Right([...errors]));
                    },
                    (a) {
                      if (runtime.isCancelled()) {
                        callback(_Right(null));
                        return;
                      }

                      callback(
                        _Left((i + 1, [...values, a])),
                      );
                    },
                    //
                  ),
                );
              } catch (error, st) {
                callback(_Right([ContError(error, st)]));
              }
            },
            escape: (either) {
              switch (either) {
                case _Left():
                  // cancellation
                  return;
                case _Right(value: final either):
                  switch (either) {
                    case _Left(value: final results):
                      observer.onValue(results);
                      return;
                    case _Right(value: final errors):
                      observer.onTerminate(errors);
                      return;
                  }
              }
            },
            //
          );
        });
      case BothMergeWhenAllPolicy():
        return Cont.fromRun((runtime, observer) {
          list = list.toList();

          if (list.isEmpty) {
            observer.onValue(<A>[]);
            return;
          }

          if (list.length == 1) {
            final cont = list[0];
            try {
              cont._run(
                runtime,
                ContObserver._(
                  (errors) {
                    if (runtime.isCancelled()) {
                      return;
                    }
                    observer.onTerminate([...errors]);
                  },
                  (a) {
                    if (runtime.isCancelled()) {
                      return;
                    }
                    observer.onValue([a]);
                  },
                ),
              );
            } catch (error, st) {
              observer.onTerminate([ContError(error, st)]);
            }
            return;
          }

          List<ContError>? seed;

          final List<A> results = [];

          var i = 0;
          for (final cont in list) {
            try {
              cont._run(
                runtime,
                ContObserver._(
                  (errors) {
                    if (runtime.isCancelled()) {
                      return;
                    }

                    i += 1;
                    final seedRefCopy = seed;
                    if (seedRefCopy == null) {
                      seed = [...errors];
                    } else {
                      final safeCopyOfResultErrors =
                          seedRefCopy + errors;

                      seed = safeCopyOfResultErrors;
                    }

                    if (i >= list.length) {
                      observer.onTerminate(seed!);
                      return;
                    }
                  },
                  (a) {
                    if (runtime.isCancelled()) {
                      return;
                    }

                    i += 1;
                    final seedCopy = seed;
                    if (seedCopy != null) {
                      if (i >= list.length) {
                        observer.onTerminate(seedCopy);
                      }
                      return;
                    }

                    results.add(a);
                    if (i >= list.length) {
                      observer.onValue(results);
                    }
                  },
                ),
                //
              );
            } catch (error, st) {
              i += 1;
              final seedCopy = seed;
              if (seedCopy == null) {
                seed = [ContError(error, st)];
              } else {
                final safeCopyOfResultErrors =
                    seedCopy + [ContError(error, st)];
                seed = safeCopyOfResultErrors;
              }

              if (i >= list.length) {
                observer.onTerminate(seed!);
                return;
              }
            }
          }
        });
      case BothQuitFastPolicy():
        return Cont.fromRun((runtime, observer) {
          list = list.toList();

          if (list.isEmpty) {
            observer.onValue(<A>[]);
            return;
          }

          bool isDone = false;
          final results = List<A?>.filled(
            list.length,
            null,
          );

          int amountOfFinishedContinuations = 0;

          final ContRuntime<E> sharedContRuntime =
              ContRuntime._(runtime.env(), () {
                return runtime.isCancelled() || isDone;
              });

          void handleTerminate(List<ContError> errors) {
            if (isDone) {
              return;
            }
            isDone = true;

            observer.onTerminate(errors);
          }

          for (final (i, cont) in list.indexed) {
            try {
              cont._run(
                sharedContRuntime,
                ContObserver._(
                  (errors) {
                    if (sharedContRuntime.isCancelled()) {
                      return;
                    }
                    handleTerminate([
                      ...errors,
                    ]); // defensive copy
                  },
                  (a) {
                    if (sharedContRuntime.isCancelled()) {
                      return;
                    }

                    results[i] = a;
                    amountOfFinishedContinuations += 1;

                    if (amountOfFinishedContinuations <
                        list.length) {
                      return;
                    }

                    observer.onValue(results.cast<A>());
                  },
                ),
              );
            } catch (error, st) {
              handleTerminate([ContError(error, st)]);
            }
          }
        });
    }
  }

  /// Races two continuations, returning the first successful value.
  ///
  /// Executes both continuations and returns the result from whichever succeeds first.
  /// If both fail, concatenates their errors. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [EitherSequencePolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [EitherMergeWhenAllPolicy]: Runs both in parallel, returns first success or merges
  ///   results using the policy's combine function if both succeed.
  /// - [EitherQuitFastPolicy]: Runs both in parallel, returns immediately on first success.
  ///
  /// - [left]: First continuation to try.
  /// - [right]: Second continuation to try.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, A> either<E, A>(
    Cont<E, A> left,
    Cont<E, A> right, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    if (left is Cont<E, Never>) {
      left = left.absurd<A>();
    }

    if (right is Cont<E, Never>) {
      right = right.absurd<A>();
    }

    switch (policy) {
      case EitherSequencePolicy<A>():
        return left.elseDo((errors1) {
          return right.elseDo((errors2) {
            return Cont.terminate(errors1 + errors2);
          });
        });
      case EitherMergeWhenAllPolicy<A>(
        combine: final combine,
      ):
        return _eitherMergeWhenAll(left, right, combine);
      case EitherQuitFastPolicy<A>():
        return _eitherQuitFast(left, right);
    }
  }

  /// Instance method for racing this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.either]. Races this continuation
  /// against [right], returning the first successful value.
  ///
  /// - [right]: The other continuation to race with.
  /// - [policy]: Execution policy determining how continuations are run.
  Cont<E, A> or(
    Cont<E, A> right, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    return Cont.either(this, right, policy: policy);
  }

  /// Races multiple continuations, returning the first successful value.
  ///
  /// Executes all continuations in [list] and returns the first one that succeeds.
  /// If all fail, collects all errors. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [EitherSequencePolicy]: Tries continuations one by one in order until one succeeds.
  /// - [EitherMergeWhenAllPolicy]: Runs all in parallel, returns first success or merges
  ///   results using the policy's combine function if multiple succeed.
  /// - [EitherQuitFastPolicy]: Runs all in parallel, returns immediately on first success.
  ///
  /// - [list]: List of continuations to race.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, A> any<E, A>(
    List<Cont<E, A>> list, {
    required ContEitherPolicy<A> policy,
    //
  }) {
    final List<Cont<E, A>> safeCopy0 =
        List<Cont<E, A>>.from(list);

    switch (policy) {
      case EitherSequencePolicy<A>():
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);

          _stackSafeLoop<
            _Either<(int, List<ContError>), _Either<(), A>>,
            (int, List<ContError>),
            _Either<(), _Either<List<ContError>, A>>
          >(
            seed: _Left((0, [])),
            keepRunningIf: (either) {
              switch (either) {
                case _Left(value: final tuple):
                  final (index, errors) = tuple;
                  if (index >= safeCopy.length) {
                    return _StackSafeLoopPolicyStop(
                      _Right(_Left(errors)),
                    );
                  }
                  return _StackSafeLoopPolicyKeepRunning((
                    index,
                    errors,
                  ));
                case _Right(value: final either):
                  switch (either) {
                    case _Left<(), A>():
                      return _StackSafeLoopPolicyStop(
                        _Left(()),
                      );
                    case _Right<(), A>(value: final a):
                      return _StackSafeLoopPolicyStop(
                        _Right(_Right(a)),
                      );
                  }
              }
            },
            computation: (tuple, callback) {
              final (index, errors) = tuple;
              Cont<E, A> cont = safeCopy[index];
              if (cont is Cont<E, Never>) {
                cont = cont.absurd<A>();
              }

              try {
                cont._run(
                  runtime,
                  ContObserver._(
                    (errors2) {
                      if (runtime.isCancelled()) {
                        callback(_Right(_Left(())));
                        return;
                      }
                      callback(
                        _Left((
                          index + 1,
                          [...errors, ...errors2],
                        )),
                      );
                    },
                    (a) {
                      if (runtime.isCancelled()) {
                        callback(_Right(_Left(())));
                        return;
                      }
                      callback(_Right(_Right(a)));
                    },
                    //
                  ),
                );
              } catch (error, st) {
                callback(
                  _Left((
                    index + 1,
                    [...errors, ContError(error, st)],
                  )),
                );
              }
            },
            escape: (either) {
              switch (either) {
                case _Left():
                  // cancellation
                  return;
                case _Right(value: final either):
                  switch (either) {
                    case _Left<List<ContError>, A>(
                      value: final errors,
                    ):
                      observer.onTerminate([...errors]);
                      return;
                    case _Right<List<ContError>, A>(
                      value: final a,
                    ):
                      observer.onValue(a);
                      return;
                  }
              }
            },
            //
          );
        });
      case EitherMergeWhenAllPolicy<A>(
        combine: final combine,
      ):
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);

          if (safeCopy.isEmpty) {
            observer.onTerminate();
            return;
          }

          if (safeCopy.length == 1) {
            final cont = safeCopy[0];
            try {
              cont._run(
                runtime,
                ContObserver._(
                  (errors) {
                    if (runtime.isCancelled()) {
                      return;
                    }
                    observer.onTerminate([...errors]);
                  },
                  (a) {
                    if (runtime.isCancelled()) {
                      return;
                    }
                    observer.onValue(a);
                  },
                ),
              );
            } catch (error, st) {
              observer.onTerminate([ContError(error, st)]);
            }
            return;
          }

          A? seed;

          final List<ContError> errors = [];

          var i = 0;

          void handleTermination(
            List<ContError> terminateErrors,
          ) {
            if (runtime.isCancelled()) {
              return;
            }
            i += 1;
            final seedCopy = seed;
            if (seedCopy != null) {
              if (i >= safeCopy.length) {
                observer.onValue(seedCopy);
              }
              return;
            }

            errors.addAll(terminateErrors);
            if (i >= safeCopy.length) {
              observer.onTerminate(errors);
            }
          }

          for (final cont in safeCopy) {
            try {
              cont._run(
                runtime,
                ContObserver._(
                  (terminateErrors) {
                    if (runtime.isCancelled()) {
                      return;
                    }
                    i += 1;
                    final seedCopy = seed;
                    if (seedCopy != null) {
                      if (i >= safeCopy.length) {
                        observer.onValue(seedCopy);
                      }
                      return;
                    }

                    errors.addAll(terminateErrors);
                    if (i >= safeCopy.length) {
                      observer.onTerminate(errors);
                    }
                  },
                  (a) {
                    if (runtime.isCancelled()) {
                      return;
                    }
                    i += 1;
                    final seedCopy = seed;
                    final A seedCopy2;
                    if (seedCopy == null) {
                      seed = a;
                      seedCopy2 = a;
                    } else {
                      try {
                        final safeCopyOfResultValue =
                            combine(seedCopy, a);
                        seed = safeCopyOfResultValue;
                        seedCopy2 = safeCopyOfResultValue;
                      } catch (error, st) {
                        i -=
                            1; // we have to remove 1 step, as we gonna increment it again below
                        handleTermination([
                          ContError(error, st),
                        ]);
                        return;
                      }
                    }

                    if (i >= safeCopy.length) {
                      observer.onValue(seedCopy2);
                      return;
                    }
                  },
                ),
                //
              );
            } catch (error, st) {
              i += 1;
              final seedCopy = seed;
              if (seedCopy != null) {
                if (i >= safeCopy.length) {
                  observer.onValue(seedCopy);
                }
                return;
              }

              errors.add(ContError(error, st));

              if (i >= safeCopy.length) {
                observer.onTerminate(errors);
                return;
              }
            }
          }
        });
      case EitherQuitFastPolicy<A>():
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);
          if (safeCopy.isEmpty) {
            observer.onTerminate();
            return;
          }

          final List<List<ContError>> resultOfErrors =
              List.generate(safeCopy.length, (_) {
                return [];
              });

          bool isWinnerFound = false;
          int numberOfFinished = 0;

          final ContRuntime<E> sharedContRuntime =
              ContRuntime._(runtime.env(), () {
                return runtime.isCancelled() ||
                    isWinnerFound;
              });

          void handleTerminate(
            int index,
            List<ContError> errors,
          ) {
            numberOfFinished += 1;

            resultOfErrors[index] = errors;

            if (numberOfFinished < safeCopy.length) {
              return;
            }

            final flattened = resultOfErrors.expand((list) {
              return list;
            }).toList();

            observer.onTerminate(flattened);
          }

          for (int i = 0; i < safeCopy.length; i++) {
            final cont = safeCopy[i];
            try {
              cont._run(
                sharedContRuntime,
                ContObserver._(
                  (errors) {
                    if (sharedContRuntime.isCancelled()) {
                      return;
                    }
                    handleTerminate(i, [
                      ...errors,
                    ]); // defensive copy
                  },
                  (a) {
                    if (sharedContRuntime.isCancelled()) {
                      return;
                    }
                    isWinnerFound = true;
                    observer.onValue(a);
                  },
                ),
              );
            } catch (error, st) {
              handleTerminate(i, [ContError(error, st)]);
            }
          }
        });
    }
  }

  /// Conditionally succeeds only when the predicate is satisfied.
  ///
  /// Filters the continuation based on the predicate. If the predicate returns
  /// `true`, the continuation succeeds with the value. If the predicate returns
  /// `false`, the continuation terminates without errors.
  ///
  /// This is useful for conditional execution where you want to treat a
  /// predicate failure as termination rather than an error.
  ///
  /// - [predicate]: Function that tests the value.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.of(42).when((n) => n > 0);
  /// // Succeeds with 42
  ///
  /// final cont2 = Cont.of(-5).when((n) => n > 0);
  /// // Terminates
  /// ```
  Cont<E, A> when(bool Function(A value) predicate) {
    return thenDo((a) {
      if (predicate(a)) {
        return Cont.of(a);
      }

      return Cont.terminate<E, A>();
    });
  }

  /// Repeatedly executes the continuation as long as the predicate returns `true`,
  /// stopping when it returns `false`.
  ///
  /// Runs the continuation in a loop, testing each result with the predicate.
  /// The loop continues as long as the predicate returns `true`, and stops
  /// successfully when the predicate returns `false`.
  ///
  /// The loop is stack-safe and handles asynchronous continuations correctly.
  /// If the continuation terminates or if the predicate throws an exception,
  /// the loop stops and propagates the errors.
  ///
  /// This is useful for retry logic, polling, or repeating an operation while
  /// a condition holds.
  ///
  /// - [predicate]: Function that tests the value. Returns `true` to continue
  ///   looping, or `false` to stop and succeed with the value.
  ///
  /// Example:
  /// ```dart
  /// // Poll an API while data is not ready
  /// final result = fetchData().asLongAs((response) => !response.isReady);
  ///
  /// // Retry while value is below threshold
  /// final value = computation().asLongAs((n) => n < 100);
  /// ```
  Cont<E, A> asLongAs(bool Function(A value) predicate) {
    return Cont.fromRun((runtime, observer) {
      _stackSafeLoop<
        _Either<
          (),
          _Either<(), _Either<A, List<ContError>>>
        >,
        (),
        _Either<(), _Either<A, List<ContError>>>
      >(
        seed: _Left(()),
        keepRunningIf: (state) {
          switch (state) {
            case _Left():
              // Keep running - need to execute the continuation again
              return _StackSafeLoopPolicyKeepRunning(());
            case _Right(value: final result):
              // Stop - we have either a successful value or termination errors
              return _StackSafeLoopPolicyStop(result);
          }
        },
        computation: (_, callback) {
          try {
            _run(
              runtime,
              ContObserver._(
                (errors) {
                  if (runtime.isCancelled()) {
                    callback(_Right(_Left(())));
                    return;
                  }
                  // Terminated - stop the loop with errors
                  callback(
                    _Right(_Right(_Right([...errors]))),
                  );
                },
                (a) {
                  if (runtime.isCancelled()) {
                    callback(_Right(_Left(())));
                    return;
                  }

                  try {
                    // Check the predicate
                    if (!predicate(a)) {
                      // Predicate satisfied - stop with success
                      callback(_Right(_Right(_Left(a))));
                    } else {
                      // Predicate not satisfied - retry
                      callback(_Left(()));
                    }
                  } catch (error, st) {
                    // Predicate threw an exception
                    callback(
                      _Right(
                        _Right(
                          _Right([ContError(error, st)]),
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          } catch (error, st) {
            callback(
              _Right(
                _Right(_Right([ContError(error, st)])),
              ),
            );
          }
        },
        escape: (result) {
          switch (result) {
            case _Left<(), _Either<A, List<ContError>>>():
              // cancellation
              return;
            case _Right<(), _Either<A, List<ContError>>>(
              value: final result,
            ):
              switch (result) {
                case _Left(value: final a):
                  observer.onValue(a);
                  return;
                case _Right(value: final errors):
                  observer.onTerminate(errors);
                  return;
              }
          }
        },
      );
    });
  }

  /// Repeatedly executes the continuation until the predicate returns `true`.
  ///
  /// Runs the continuation in a loop, testing each result with the predicate.
  /// The loop continues while the predicate returns `false`, and stops
  /// successfully when the predicate returns `true`.
  ///
  /// This is the inverse of [asLongAs] - implemented as `asLongAs((a) => !predicate(a))`.
  /// Use this when you want to retry until a condition is met.
  ///
  /// - [predicate]: Function that tests the value. Returns `true` to stop the loop
  ///   and succeed, or `false` to continue looping.
  ///
  /// Example:
  /// ```dart
  /// // Retry until a condition is met
  /// final result = fetchStatus().until((status) => status == 'complete');
  ///
  /// // Poll until a threshold is reached
  /// final value = checkProgress().until((progress) => progress >= 100);
  /// ```
  Cont<E, A> until(bool Function(A value) predicate) {
    return asLongAs((a) {
      return !predicate(a);
    });
  }

  /// Repeatedly executes the continuation indefinitely.
  ///
  /// Runs the continuation in an infinite loop that never stops on its own.
  /// The loop only terminates if the underlying continuation terminates with
  /// an error.
  ///
  /// The return type [Cont]<[E], [Never]> indicates that this continuation never
  /// produces a value - it either runs forever or terminates with errors.
  ///
  /// This is useful for:
  /// - Daemon-like processes that run continuously
  /// - Server loops that handle requests indefinitely
  /// - Event loops that continuously process events
  /// - Background tasks that should never stop
  ///
  /// Example:
  /// ```dart
  /// // A server that handles requests forever
  /// final server = acceptConnection()
  ///     .then((conn) => handleConnection(conn))
  ///     .forever();
  ///
  /// // Run with only a termination handler (using trap extension)
  /// server.trap(env, (errors) => print('Server stopped: $errors'));
  /// ```
  Cont<E, Never> forever() {
    return until((_) {
      return false;
    }).map((value) {
      return value as Never;
    });
  }

  /// Manages resource lifecycle with guaranteed cleanup.
  ///
  /// The bracket pattern ensures that a resource is properly released after use,
  /// even if an error occurs during the [use] phase or if cancellation occurs.
  /// This is the functional equivalent of try-with-resources or using statements.
  ///
  /// The execution order is:
  /// 1. [acquire] - Obtain the resource
  /// 2. [use] - Use the resource to produce a value
  /// 3. [release] - Release the resource (always runs, even if [use] fails or is cancelled)
  ///
  /// Cancellation behavior:
  /// - The [release] function is called even when the runtime is cancelled
  /// - This ensures resources are properly cleaned up regardless of cancellation
  /// - However, if cancellation occurs during release itself, cleanup may be partial
  ///
  /// Error handling behavior:
  /// - If [use] succeeds and [release] succeeds: returns the value from [use]
  /// - If [use] succeeds and [release] fails: terminates with release errors
  /// - If [use] fails and [release] succeeds: terminates with use errors
  /// - If [use] fails and [release] fails: terminates with both errors combined
  ///
  /// Example:
  /// ```dart
  /// final result = Cont.bracket<File, String>(
  ///   acquire: openFile('data.txt'),           // acquire
  ///   release: (file) => closeFile(file),      // release
  ///   use: (file) => readContents(file),   // use
  /// );
  /// ```
  static Cont<E, A> bracket<E, R, A>({
    required Cont<E, R> acquire,
    required Cont<E, ()> Function(R resource) release,
    required Cont<E, A> Function(R resource) use,
    //
  }) {
    if (acquire is Cont<E, Never>) {
      acquire = acquire.absurd<R>();
    }

    return acquire.thenDo((resource) {
      return Cont.fromRun((runtime, observer) {
        // Create a non-cancellable runtime for the release phase
        // This ensures release always runs, even if the parent is cancelled
        final releaseRuntime = ContRuntime<E>._(
          runtime.env(),
          () {
            return false;
          },
        );

        // Helper to safely call release and handle its result
        // Uses _Either to distinguish between success (value) and failure (errors)
        void doRelease(
          _Either<A, List<ContError>> useResult,
        ) {
          // Create helper to get release continuation safely
          Cont<E, ()> getReleaseCont() {
            try {
              final cont = release(resource);
              if (cont is Cont<E, Never>) {
                return cont.absurd<()>();
              }
              return cont;
            } catch (error, st) {
              return Cont.terminate<E, ()>([
                ContError(error, st),
              ]);
            }
          }

          // Run release with non-cancellable runtime
          try {
            final releaseCont = getReleaseCont();
            releaseCont._run(
              releaseRuntime, // Use non-cancellable runtime
              ContObserver._(
                // Release terminated - combine with use errors if any
                (releaseErrors) {
                  switch (useResult) {
                    case _Left<A, List<ContError>>():
                      // Use succeeded but release failed
                      observer.onTerminate([
                        ...releaseErrors,
                      ]);
                    case _Right<A, List<ContError>>(
                      value: final useErrors,
                    ):
                      // Both use and release failed - combine errors
                      final combinedErrors = [
                        ...useErrors,
                        ...releaseErrors,
                      ];
                      observer.onTerminate(combinedErrors);
                  }
                },
                // Release succeeded
                (_) {
                  switch (useResult) {
                    case _Left<A, List<ContError>>(
                      value: final value,
                    ):
                      // Both use and release succeeded - return the value
                      observer.onValue(value);
                    case _Right<A, List<ContError>>(
                      value: final useErrors,
                    ):
                      // Use failed but release succeeded - propagate use errors
                      observer.onTerminate(useErrors);
                  }
                },
              ),
            );
          } catch (error, st) {
            // Exception while setting up release
            switch (useResult) {
              case _Left<A, List<ContError>>():
                // Use succeeded but release setup failed
                observer.onTerminate([
                  ContError(error, st),
                ]);
              case _Right<A, List<ContError>>(
                value: final useErrors,
              ):
                // Both use and release setup failed
                final combinedErrors = [
                  ...useErrors,
                  ContError(error, st),
                ];
                observer.onTerminate(combinedErrors);
            }
          }
        }

        // Check cancellation before starting use phase
        if (runtime.isCancelled()) {
          // Still attempt to release the resource even if cancelled
          doRelease(_Right(const []));
          return;
        }

        // Execute the use phase
        try {
          Cont<E, A> useCont = use(resource);
          if (useCont is Cont<E, Never>) {
            useCont = useCont.absurd<A>();
          }

          useCont._run(
            runtime,
            ContObserver._(
              // Use phase terminated
              (useErrors) {
                // Always release, even on termination
                doRelease(_Right([...useErrors]));
              },
              // Use phase succeeded
              (value) {
                // Always release after successful use
                doRelease(_Left(value));
              },
            ),
          );
        } catch (error, st) {
          // Exception while setting up use phase - still release
          doRelease(_Right([ContError(error, st)]));
        }
      });
    });
  }
}

/// Extension providing flatten operation for nested continuations.
extension ContFlattenExtension<E, A>
    on Cont<E, Cont<E, A>> {
  /// Flattens a nested [Cont] structure.
  ///
  /// Converts [Cont]<[E], [Cont]<[E], [A]>> to [Cont]<[E], [A]>.
  /// Equivalent to `then((contA) => contA)`.
  Cont<E, A> flatten() {
    return thenDo((contA) {
      return contA;
    });
  }
}

/// Extension for running continuations that never produce a value.
///
/// This extension provides specialized methods for [Cont]<[E], [Never]> where only
/// termination is expected, simplifying the API by removing the unused value callback.
extension ContRunExtension<E> on Cont<E, Never> {
  /// Executes the continuation expecting only termination.
  ///
  /// This is a convenience method for [Cont]<[E], [Never]> that executes the
  /// continuation with only a termination handler, since a value callback
  /// would never be called for a [Cont]<[E], [Never]>.
  ///
  /// - [env]: The environment value to provide as context during execution.
  /// - [onTerminate]: Callback invoked when the continuation terminates with errors.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.terminate<MyEnv, Never>([ContError(Exception('Failed'), StackTrace.current)]);
  /// cont.trap(myEnv, (errors) {
  ///   print('Terminated with ${errors.length} error(s)');
  /// });
  /// ```
  void trap(
    E env,
    void Function(List<ContError>) onTerminate,
  ) {
    run(env, onTerminate, (_) {});
  }

  /// Converts a continuation that never produces a value to any desired type.
  ///
  /// The absurd method implements the principle of "ex falso quodlibet" (from
  /// falsehood, anything follows) from type theory. It allows converting a
  /// `Cont<E, Never>` to `Cont<E, A>` for any type `A`.
  ///
  /// Since `Never` is an uninhabited type with no possible values, the mapping
  /// function `(Never never) => never` can never actually execute. However, the
  /// type system accepts this transformation as valid, enabling type-safe
  /// conversion from a continuation that cannot produce a value to one with
  /// any desired value type.
  ///
  /// This is particularly useful when:
  /// - Working with continuations that run forever (e.g., from [forever])
  /// - Matching types with other continuations in composition
  /// - Converting terminating-only continuations to typed continuations
  ///
  /// Type parameters:
  /// - [A]: The desired value type for the resulting continuation
  ///
  /// Returns a continuation with the same environment type but a different
  /// value type parameter.
  ///
  /// Example:
  /// ```dart
  /// // A server that runs forever has type Cont<Env, Never>
  /// final server = handleRequests().forever();
  ///
  /// // Convert to Cont<Env, String> to match other continuation types
  /// final serverAsString = server.absurd<String>();
  /// ```
  Cont<E, A> absurd<A>() {
    return map<A>((
      Never // gonna give you up
      never, // gonna let you down
    ) {
      return never; // gonna run around and desert you
    });
  }

  /*
  ..:..............:::------:::::::::----:-:::.::-----:::--::----::::::::----------:::::::::..........
................::::-------::::::::---::::::--=-=+*++*##**++=--:::::::----------:::::::::....:......
..............::::::::--:--:::::::::---::.:-*##########*******=::::::::----------::::..:...........:
..........::::::..::::::::-----------------=+*###############**+--------------------:..:............
.......:::::::....::::::...:----:::..:-:-=+***######%%#######***+------:::--------------:...........
..:::::::::::.....::::::.::--::::::::-===++**##################*+-------::------::-------:..........
:::::::::::::.....::::::::::::.......::-=++*++++=====+=----==*##*=:.------------::------------:.....
:::.....:::::.....::::::::............:=*#*+=++====----------=+**=:::-----------:::.:----------::...
:::........:::....:::::::::.:........:-*#*++++++====--=-------=**=::::::--------::::-----::::----::.
:..........::::...::::::::...........:-***+++++++===--==-----==**=::::::--------::::---:::::::----::
:........:::::::::::::::::...........:-+*++++*+++**+=-=+++=====*+-:::::---------::----::::::::::---:
::::.....:::...::::::::::.........::..:+++++++**+++++=-=+*+====+:......:-----------:----:::::::::--:
::::::..::.......:::::::::..........:====-=++====++++=--=======-....:::::---------:::----::::-----::
:....::::........::::::::::::.......-=++=-=+++==+++++=--------==::..:.::---------::::::----------:::
:......::...... ..::::::::--::.......-+====++++++++**++=-----==-:::.:-----------::::..::---------:::
:.......::.......:::::::..:---:.....:-==+++++++++++==-=-----===:::::-----:-------:.:.:.:--:..:::----
:........:........::::::..::------------:-=++++++++===--------:::------::::------:.:...:-:.....:----
:........:.......::::::::-------------.::-=++++++++===--==--------------::-------:.....:-:.......:--
:::......::......:::::::::-::...:.:---:---==+++++=====--===----:::.:-------------:.....-:......::---
::::......:......:::::::::::.:....::--:::-++++++++===-====-:---::::::::----------:::..:-:.....::::--
:::::.....::.....::::::::...:...::-------=+++++++++++=====-----::..::.::---------:::.:--:.....::::::
..::::...:::::::.:::::::....:::----------=+++++++++=======-::-----::::::::-------:::----:....::::...
.:::::::::....::::::::::...:.::----::::--=+++++++=========-==::----::::::::--------------:.:--::....
------::::......::::::---::::---------:-=+++++++++========:+##=:----::::::----------:::---:---::....
--------::.:....::::-------:--==+++=-=::---=+++++========--*####*=---::::---------::::::----------:.
::------:.......:---------=++*#####+=++++*++++++++===++=:-+###%%%%%#*+-::---------:::::::-----------
.---------:::..:-----==+*##%%%%%%%#*=++++++====++++++=-::=##%%%%%%%%%%%##*=::-----::::::-------:....
.--::-----:....:=++**##%%%%%%%%%%%%#=+*++++=+==++++--::::=#%%%%%%%%%%%%%%%%%##=::::::::---------::::
:--:..:----:..:=##%%%%%%%%%%%%%%%%%#=+***++-=+++=--:::::-*%%%%%%%%%#*+#%%%%%%%%%#*-::::-----:---::::
:-::.::-----::-*%%%%%%#%%%%%%%%%%%%#=+***++===---::::::=#%%%%%%%%#*+++===+#%%%%%%%%#*:-----:::---:::
:::....:----::+#%%%%%%%%%%%%%%%%%%%%******++*+++++=-::=%%%%%%%%%%*+++++++===*%%%%%%%#*------::---:::
:::.:..:------*#%%%%%%%%%%%%%%%%%%%%****++=***++===++*%%%%%%%%%%#+++++======+#%%%%%%##+---:::::---::
::...::--::--=#%%%%%%%%%%%%%%%%%%%%%%%*==+**+=--=++*##%%%%%%%%%%#++++=======+%%%%%%%%#+:--::::::--::
-:..:----:::-=#%%%%%%%%%%%%%%%%%%%%%%%#======++**#***#%%%%%%%%%%%#**+======+*%%%%%%%%%*-----::::---:
-:::-------:+*#%%%%%%%%%%%%%%%%%%%%%%%+-==+*###**+==+%%%%%%%%%%%%%%*++=====+#%%%%%%%%#*------:::---:
::----:::--=*#%%%%%%%%%%%%%%%%%%%%%%%%+-==***+=--=+*%%%%%%%%%%%%%%%*++=====+#%%%%%%%%#*-------::---:
----:.....:+#%%%%%%%%%%%%%%%%%%%%%%%%%+--==--=+*#%%%%%%%%%%%%%%%%@%#*++====+#%%%%%%%%%*::::---------
---::::.:::+%%%%%%%%%%%%%%%%%%%%%%%%%%*==+##%%%%#+=+%%%%%%%%%%%%%@@%**+====+#%%%%%%%%%*:::::::------
-:.......:-+%%%%%%%%%%%%%%%%%%%%%%%%%%%**##*+=====+#%%%%%%%%%%%%@@@@%**++===+%%%%%%%%%#-::::::------
:........:-*%%%%%%%%%%%@%%%%%%%%%%%%%%%**+===+*#%%%%%%%%%%%%%%%@@@@@@@%%%%%%#%%%%%%%%%#=:::::::::---
:........:=*%%%%%%%%%%%@%%%%%%%%%%%%%%%**####%%#***%%%%%%%%%%@@@@@@@@@@@%####%%%%%%%%%#=::::--:-----
-::...:::=+#%%%%%@@@@@@@@@@%%%%@%%%%%%%**##*+++++*#%%%%%%%%@@@@@@@@@@@@@%%%%%%%%##%%%%%*-::::::::---
---:::::=++#%%%%%@@@@@@@@@@@%%@@%%%%%%%***+++**##%%@%@%%%@@@@@@@@@@@@@@@@@@@@%%%%#%%%%%%#=-:::------
----::-*###%%%%%@@@@@@@@@@@@%#+++++++++**#########%%%%%%%@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%*-::-------
:----+%%%%%@@@@@@@@@@%@@@@@#**+++++*+++**####**++*%@%%@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%*=------=-
::--=##%%%##%%%%%%%%*##**#*++++++++++++*********#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%%%%*----==
:::-*%%%%%%#*###%%%#**##%%#****++++++++*****###%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%%%%%*=-==
--:-*%%%###%%%%%@%#*%%%%%%#****++*++++***%%%%%%#*#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%@%%%@%%%%%*==
:::--*%#%%%%%%%@%%#%%%%%%%#****++*++++%****+++**#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%@%%%%%#==
::-===#%%%%%%%%%%%%%@@@%%%##*******#%@@#****###%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%@@%%%%+==
:--===#%%%%%%%%%%%%%%%%@@@@@%%%@@@@@@@@##%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%@%%%+===
-=----*%%%%%%%%%%%###%%%%%%%@@@@@@@@@@@#********#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%*-===
----:--=*#%%%%%%%%%#%%@@@@@@@@@@@@@@@@%#*####%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%#=====
::::....:::--=========-================--==------=============================================::::::

   */
}
