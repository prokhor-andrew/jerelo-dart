import 'package:jerelo/jerelo.dart';

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
  final void Function(ContRuntime<E> runtime, ContObserver<A> observer) _run;

  /// Executes the continuation with separate callbacks for termination and value.
  ///
  /// Initiates execution of the continuation with separate handlers for success
  /// and failure cases.
  ///
  /// - [env]: The environment value to provide as context during execution.
  /// - [onTerminate]: Callback invoked when the continuation terminates with errors.
  /// - [onValue]: Callback invoked when the continuation produces a successful value.
  void run(E env, void Function(List<ContError> errors) onTerminate, void Function(A value) onValue) {
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
  static Cont<E, A> fromRun<E, A>(void Function(ContRuntime<E> runtime, ContObserver<A> observer) run) {
    return Cont._((runtime, observer) {
      if (runtime.isCancelled()) {
        return;
      }

      bool isDone = false;

      void guardedTerminate(List<ContError> errors) {
        if (runtime.isCancelled()) {
          return;
        }

        if (isDone) {
          return;
        }
        isDone = true;
        observer.onTerminate([...errors]);
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
        run(runtime, ContObserver._(guardedTerminate, guardedValue));
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
  static Cont<E, A> fromDeferred<E, A>(Cont<E, A> Function() thunk) {
    return Cont.fromRun((runtime, observer) {
      thunk()._run(runtime, observer);
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
  static Cont<E, A> terminate<E, A>([List<ContError> errors = const []]) {
    final safeCopyErrors0 = List<ContError>.from(errors);
    return Cont.fromRun((runtime, observer) {
      final safeCopyErrors = List<ContError>.from(safeCopyErrors0);
      observer.onTerminate(safeCopyErrors);
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
            final contA2 = f(a);
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
      return f(a).as(a);
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
  Cont<E, A3> thenZip<A2, A3>(Cont<E, A2> Function(A value) f, A3 Function(A a1, A2 a2) combine) {
    return thenDo((a1) {
      return f(a1).map((a2) {
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
  Cont<E, A3> thenZip0<A2, A3>(Cont<E, A2> Function() f, A3 Function(A a1, A2 a2) combine) {
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
      final contA2 = f(a); // this should not be inside try-catch block

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
  Cont<E, A> elseDo(Cont<E, A> Function(List<ContError> errors) f) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnTerminate((errors) {
          if (runtime.isCancelled()) {
            return;
          }
          final safeErrors = List<ContError>.from(errors);
          try {
            f([...safeErrors])._run(
              runtime,
              observer.copyUpdateOnTerminate((errors2) {
                if (runtime.isCancelled()) {
                  return;
                }
                observer.onTerminate([...errors2]);
              }),
            );
          } catch (error, st) {
            observer.onTerminate([ContError(error, st)]); // we return latest error
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
  Cont<E, A> elseTap(Cont<E, A> Function(List<ContError> errors) f) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnTerminate((errors) {
          if (runtime.isCancelled()) {
            return;
          }
          final safeErrors = List<ContError>.from(errors);
          try {
            final cont = f([...safeErrors]);
            cont._run(
              runtime,
              observer.copyUpdateOnTerminate((_) {
                if (runtime.isCancelled()) {
                  return;
                }
                observer.onTerminate(safeErrors);
              }),
            );
          } catch (_) {
            // we return original errors
            observer.onTerminate(safeErrors);
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
  /// terminates, combines errors from both attempts using the provided [combine]
  /// function before terminating.
  ///
  /// Unlike [elseDo], which only keeps the second error list, this method
  /// accumulates and combines errors from both attempts.
  ///
  /// - [f]: Function that receives original errors and produces a fallback continuation.
  /// - [combine]: Function to combine error lists from both attempts.
  Cont<E, A> elseZip(Cont<E, A> Function(List<ContError>) f, List<ContError> Function(List<ContError>, List<ContError>) combine) {
    return Cont.fromRun((runtime, observer) {
      _run(
        runtime,
        observer.copyUpdateOnTerminate((errors) {
          if (runtime.isCancelled()) {
            return;
          }
          final safeErrors = List<ContError>.from(errors);
          try {
            final cont = f([...safeErrors]);
            cont._run(
              runtime,
              observer.copyUpdateOnTerminate((errors2) {
                if (runtime.isCancelled()) {
                  return;
                }
                observer.onTerminate([
                  ...combine(safeErrors, [...errors2]),
                ]);
              }),
            );
          } catch (error, st) {
            observer.onTerminate([
              ...combine(safeErrors, [ContError(error, st)]),
            ]);
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
  /// - [combine]: Function to combine error lists from both attempts.
  Cont<E, A> elseZip0(Cont<E, A> Function() f, List<ContError> Function(List<ContError>, List<ContError>) combine) {
    return elseZip((_) {
      return f();
    }, combine);
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// If the continuation terminates, starts the side-effect continuation without waiting
  /// for it to complete. Unlike [elseTap], this does not wait for the side-effect to
  /// finish before propagating the termination. Any errors from the side-effect are
  /// silently ignored.
  ///
  /// - [f]: Function that returns a side-effect continuation.
  Cont<E, A> elseFork<A2>(Cont<E, A2> Function(List<ContError> errors) f) {
    return elseDoWithEnv((e, errors) {
      final cont = f([...errors]); // this should not be inside try-catch block
      try {
        cont.ff(e);
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
  Cont<E, A2> thenDoWithEnv<A2>(Cont<E, A2> Function(E env, A a) f) {
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
  Cont<E, A2> thenDoWithEnv0<A2>(Cont<E, A2> Function(E env) f) {
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
  Cont<E, A> thenTapWithEnv<A2>(Cont<E, A2> Function(E env, A a) f) {
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
  Cont<E, A> thenTapWithEnv0<A2>(Cont<E, A2> Function(E env) f) {
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
  Cont<E, A3> thenZipWithEnv<A2, A3>(Cont<E, A2> Function(E env, A value) f, A3 Function(A a1, A2 a2) combine) {
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
  Cont<E, A3> thenZipWithEnv0<A2, A3>(Cont<E, A2> Function(E env) f, A3 Function(A a1, A2 a2) combine) {
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
  Cont<E, A> thenForkWithEnv<A2>(Cont<E, A2> Function(E env, A a) f) {
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
  Cont<E, A> thenForkWithEnv0<A2>(Cont<E, A2> Function(E env) f) {
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
  Cont<E, A> elseDoWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f) {
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
  Cont<E, A> elseTapWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f) {
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
  /// their errors are combined using the [combine] function. This is useful when
  /// error recovery strategies need access to configuration or context.
  ///
  /// - [f]: Function that takes the environment and errors, and produces a fallback continuation.
  /// - [combine]: Function to combine error lists from both attempts.
  Cont<E, A> elseZipWithEnv(Cont<E, A> Function(E env, List<ContError>) f, List<ContError> Function(List<ContError>, List<ContError>) combine) {
    return Cont.ask<E>().thenDo((e) {
      return elseZip((errors) {
        return f(e, [...errors]);
      }, combine);
    });
  }

  /// Attempts a fallback continuation with access to the environment only and combines errors.
  ///
  /// Similar to [elseZipWithEnv], but the fallback function only receives the
  /// environment and ignores the original error information.
  ///
  /// - [f]: Function that takes the environment and produces a fallback continuation.
  /// - [combine]: Function to combine error lists from both attempts.
  Cont<E, A> elseZipWithEnv0(Cont<E, A> Function(E env) f, List<ContError> Function(List<ContError>, List<ContError>) combine) {
    return elseZipWithEnv((e, _) {
      return f(e);
    }, combine);
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [elseFork], but the side-effect function receives both the errors
  /// and the environment. The side-effect is started without waiting for it to complete,
  /// and any errors from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the environment and errors, and returns a side-effect continuation.
  Cont<E, A> elseForkWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f) {
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
  Cont<E, A> elseForkWithEnv0(Cont<E, A> Function(E env) f) {
    return elseForkWithEnv((e, _) {
      return f(e);
    });
  }

  Cont<E, A2> injectInto<A2>(Cont<A, A2> cont) {
    return thenDo((a) {
      return cont.scope(a);
    });
  }

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
  /// - [SequencePolicy]: Runs [left] then [right] sequentially.
  /// - [MergeWhenAllPolicy]: Runs both in parallel, waits for both to complete,
  ///   and merges errors if both fail.
  /// - [QuitFastPolicy]: Runs both in parallel, terminates immediately if either fails.
  ///
  /// - [left]: First continuation to execute.
  /// - [right]: Second continuation to execute.
  /// - [combine]: Function to combine both successful values.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, A3> both<E, A1, A2, A3>(
    Cont<E, A1> left,
    Cont<E, A2> right,
    A3 Function(A1 a, A2 a2) combine, {
    required ContPolicy<List<ContError>> policy,
    //
  }) {
    switch (policy) {
      case SequencePolicy<List<ContError>>():
        return left.thenDo((a) {
          return right.map((a2) {
            return combine(a, a2);
          });
        });
      case MergeWhenAllPolicy<List<ContError>>(combine: final combine2):
        return _both(left, right, combine, combine2);
      case QuitFastPolicy<List<ContError>>():
        return Cont.fromRun((runtime, observer) {
          bool isDone = false;
          bool isOneValue = false;

          A1? outerA1;
          A2? outerA2;
          final List<ContError> resultErrors = [];

          final ContRuntime<E> sharedContRuntime = ContRuntime._(runtime.env(), () {
            return runtime.isCancelled() || isDone;
          });

          void handleValue() {
            if (!isOneValue) {
              isOneValue = true;
              return;
            }

            isDone = true;
            try {
              final c = combine(outerA1 as A1, outerA2 as A2);
              observer.onValue(c);
            } catch (error, st) {
              observer.onTerminate([ContError(error, st)]);
            }
          }

          void handleTerminate(void Function() codeToUpdate) {
            isDone = true;
            codeToUpdate();
            observer.onTerminate(resultErrors);
          }

          try {
            left._run(
              sharedContRuntime,
              ContObserver._(
                (errors) {
                  if (sharedContRuntime.isCancelled()) {
                    return;
                  }
                  handleTerminate(() {
                    resultErrors.insertAll(0, errors);
                  });
                },
                (a) {
                  if (sharedContRuntime.isCancelled()) {
                    return;
                  }
                  // strict order must be followed
                  outerA1 = a;
                  handleValue();
                },
              ),
            );
          } catch (error, st) {
            handleTerminate(() {
              resultErrors.insert(0, ContError(error, st));
            });
          }

          try {
            right._run(
              sharedContRuntime,
              ContObserver._(
                (errors) {
                  if (sharedContRuntime.isCancelled()) {
                    return;
                  }
                  handleTerminate(() {
                    resultErrors.addAll(errors);
                  });
                },
                (a2) {
                  if (sharedContRuntime.isCancelled()) {
                    return;
                  }
                  // strict order must be followed
                  outerA2 = a2;
                  handleValue();
                },
              ),
            );
          } catch (error, st) {
            handleTerminate(() {
              resultErrors.add(ContError(error, st));
            });
          }
        });
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
    required ContPolicy<List<ContError>> policy,
    //
  }) {
    return Cont.both(this, right, combine, policy: policy);
  }

  /// Runs multiple continuations and collects all results according to the specified policy.
  ///
  /// Executes all continuations in [list] and collects their values into a list.
  /// The execution behavior depends on the provided [policy]:
  ///
  /// - [SequencePolicy]: Runs continuations one by one in order, stops at first failure.
  /// - [MergeWhenAllPolicy]: Runs all in parallel, waits for all to complete,
  ///   and merges errors if any fail.
  /// - [QuitFastPolicy]: Runs all in parallel, terminates immediately on first failure.
  ///
  /// - [list]: List of continuations to execute.
  /// - [policy]: Execution policy determining how continuations are run and errors are handled.
  static Cont<E, List<A>> all<E, A>(
    List<Cont<E, A>> list, {
    required ContPolicy<List<ContError>> policy,
    //
  }) {
    final safeCopy0 = List<Cont<E, A>>.from(list);
    switch (policy) {
      case SequencePolicy<List<ContError>>():
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);
          _stackSafeLoop<_Either<(int, List<A>), List<ContError>?>, (int, List<A>), _Either<(), _Either<List<A>, List<ContError>>>>(
            seed: _Value1((0, [])),
            keepRunningIf: (state) {
              switch (state) {
                case _Value1(value: final value):
                  final (index, results) = value;
                  if (index >= safeCopy.length) {
                    return _StackSafeLoopPolicyStop(_Value2(_Value1(results)));
                  }
                  return _StackSafeLoopPolicyKeepRunning((index, results));
                case _Value2(value: final value):
                  if (value != null) {
                    return _StackSafeLoopPolicyStop(_Value2(_Value2(value)));
                  } else {
                    return _StackSafeLoopPolicyStop(_Value1(()));
                  }
              }
            },
            computation: (tuple, callback) {
              final (i, values) = tuple;
              final cont = safeCopy[i];
              try {
                cont._run(
                  runtime,
                  ContObserver._(
                    (errors) {
                      if (runtime.isCancelled()) {
                        callback(_Value2(null));
                        return;
                      }
                      callback(_Value2([...errors]));
                    },
                    (a) {
                      if (runtime.isCancelled()) {
                        callback(_Value2(null));
                        return;
                      }

                      callback(_Value1((i + 1, [...values, a])));
                    },
                    //
                  ),
                );
              } catch (error, st) {
                callback(_Value2([ContError(error, st)]));
              }
            },
            escape: (either) {
              switch (either) {
                case _Value1():
                  // cancellation
                  return;
                case _Value2(value: final either):
                  switch (either) {
                    case _Value1(value: final results):
                      observer.onValue(results);
                      return;
                    case _Value2(value: final errors):
                      observer.onTerminate(errors);
                      return;
                  }
              }
            },
            //
          );
        });
      case MergeWhenAllPolicy<List<ContError>>(combine: final merge):
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);

          if (safeCopy.isEmpty) {
            observer.onValue(<A>[]);
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
          for (final cont in safeCopy) {
            try {
              cont._run(
                runtime,
                ContObserver._(
                  (errors) {
                    if (runtime.isCancelled()) {
                      return;
                    }

                    i += 1;
                    final seedCopy = seed;
                    if (seedCopy == null) {
                      seed = [...errors];
                    } else {
                      final safeCopyOfResultErrors = [...merge(seedCopy, errors)];
                      seed = safeCopyOfResultErrors;
                    }

                    if (i >= safeCopy.length) {
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
                      if (i >= safeCopy.length) {
                        observer.onTerminate(seedCopy);
                      }
                      return;
                    }

                    results.add(a);
                    if (i >= safeCopy.length) {
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
                final safeCopyOfResultErrors = [
                  ...merge(seedCopy, [ContError(error, st)]),
                ];
                seed = safeCopyOfResultErrors;
              }

              if (i >= safeCopy.length) {
                observer.onTerminate(seed!);
                return;
              }
            }
          }
        });
      case QuitFastPolicy<List<ContError>>():
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);

          if (safeCopy.isEmpty) {
            observer.onValue(<A>[]);
            return;
          }

          bool isDone = false;
          final results = List<A?>.filled(safeCopy.length, null);

          int amountOfFinishedContinuations = 0;

          final ContRuntime<E> sharedContRuntime = ContRuntime._(runtime.env(), () {
            return runtime.isCancelled() || isDone;
          });

          void handleTerminate(List<ContError> errors) {
            if (isDone) {
              return;
            }
            isDone = true;

            observer.onTerminate(errors);
          }

          for (final (i, cont) in safeCopy.indexed) {
            try {
              cont._run(
                sharedContRuntime,
                ContObserver._(
                  (errors) {
                    if (sharedContRuntime.isCancelled()) {
                      return;
                    }
                    handleTerminate([...errors]); // defensive copy
                  },
                  (a) {
                    if (sharedContRuntime.isCancelled()) {
                      return;
                    }

                    results[i] = a;
                    amountOfFinishedContinuations += 1;

                    if (amountOfFinishedContinuations < safeCopy.length) {
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
  /// If both fail, combines their errors using [combine]. The execution behavior
  /// depends on the provided [policy]:
  ///
  /// - [SequencePolicy]: Tries [left] first, then [right] if [left] fails.
  /// - [MergeWhenAllPolicy]: Runs both in parallel, returns first success or merges
  ///   results/errors if both complete.
  /// - [QuitFastPolicy]: Runs both in parallel, returns immediately on first success.
  ///
  /// - [left]: First continuation to try.
  /// - [right]: Second continuation to try.
  /// - [combine]: Function to combine error lists if both fail.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, A> either<E, A>(
    Cont<E, A> left,
    Cont<E, A> right,
    List<ContError> Function(List<ContError>, List<ContError>) combine, {
    required ContPolicy<A> policy,
    //
  }) {
    switch (policy) {
      case SequencePolicy<A>():
        return left.elseDo((errors1) {
          return right.elseDo((errors2) {
            return Cont.terminate(combine(errors1, errors2));
          });
        });
      case MergeWhenAllPolicy<A>(combine: final combine2):
        return _either(left, right, combine, combine2);
      case QuitFastPolicy<A>():
        return Cont.fromRun((runtime, observer) {
          bool isOneFailed = false;
          final List<ContError> resultErrors = [];
          bool isDone = false;

          final ContRuntime<E> sharedContRuntime = ContRuntime._(runtime.env(), () {
            return runtime.isCancelled() || isDone;
          });

          void handleTerminate(void Function() codeToUpdateState) {
            if (isOneFailed) {
              codeToUpdateState();

              observer.onTerminate(resultErrors);
              return;
            }
            isOneFailed = true;

            codeToUpdateState();
          }

          ContObserver<A> makeObserver(void Function(List<ContError> errors) codeToUpdateState) {
            return ContObserver._(
              (errors) {
                if (sharedContRuntime.isCancelled()) {
                  return;
                }

                handleTerminate(() {
                  codeToUpdateState([...errors]);
                });
              },
              (a) {
                if (sharedContRuntime.isCancelled()) {
                  return;
                }

                isDone = true;
                observer.onValue(a);
              },
            );
          }

          try {
            left._run(
              sharedContRuntime,
              makeObserver((errors) {
                resultErrors.insertAll(0, errors);
              }),
            );
          } catch (error, st) {
            handleTerminate(() {
              resultErrors.insert(0, ContError(error, st));
            });
          }

          try {
            right._run(
              sharedContRuntime,
              makeObserver((errors) {
                resultErrors.addAll(errors);
              }),
            );
          } catch (error, st) {
            handleTerminate(() {
              resultErrors.add(ContError(error, st));
            });
          }
        });
    }
  }

  /// Instance method for racing this continuation with another.
  ///
  /// Convenient instance method wrapper for [Cont.either]. Races this continuation
  /// against [right], returning the first successful value.
  ///
  /// - [right]: The other continuation to race with.
  /// - [combine]: Function to combine error lists if both fail.
  /// - [policy]: Execution policy determining how continuations are run.
  Cont<E, A> or(
    Cont<E, A> right,
    List<ContError> Function(List<ContError>, List<ContError>) combine, {
    required ContPolicy<A> policy,
    //
  }) {
    return Cont.either(this, right, combine, policy: policy);
  }

  /// Races multiple continuations, returning the first successful value.
  ///
  /// Executes all continuations in [list] and returns the first one that succeeds.
  /// If all fail, collects all errors. The execution behavior depends on the
  /// provided [policy]:
  ///
  /// - [SequencePolicy]: Tries continuations one by one in order until one succeeds.
  /// - [MergeWhenAllPolicy]: Runs all in parallel, returns first success or merges
  ///   results if all complete.
  /// - [QuitFastPolicy]: Runs all in parallel, returns immediately on first success.
  ///
  /// - [list]: List of continuations to race.
  /// - [policy]: Execution policy determining how continuations are run.
  static Cont<E, A> any<E, A>(
    List<Cont<E, A>> list, {
    required ContPolicy<A> policy,
    //
  }) {
    final List<Cont<E, A>> safeCopy0 = List<Cont<E, A>>.from(list);

    switch (policy) {
      case SequencePolicy<A>():
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);

          _stackSafeLoop<_Either<(int, List<ContError>), _Either<(), A>>, (int, List<ContError>), _Either<(), _Either<List<ContError>, A>>>(
            seed: _Value1((0, [])),
            keepRunningIf: (either) {
              switch (either) {
                case _Value1(value: final tuple):
                  final (index, errors) = tuple;
                  if (index >= safeCopy.length) {
                    return _StackSafeLoopPolicyStop(_Value2(_Value1(errors)));
                  }
                  return _StackSafeLoopPolicyKeepRunning((index, errors));
                case _Value2(value: final either):
                  switch (either) {
                    case _Value1<(), A>():
                      return _StackSafeLoopPolicyStop(_Value1(()));
                    case _Value2<(), A>(value: final a):
                      return _StackSafeLoopPolicyStop(_Value2(_Value2(a)));
                  }
              }
            },
            computation: (tuple, callback) {
              final (index, errors) = tuple;
              final cont = safeCopy[index];

              try {
                cont._run(
                  runtime,
                  ContObserver._(
                    (errors2) {
                      if (runtime.isCancelled()) {
                        callback(_Value2(_Value1(())));
                        return;
                      }
                      callback(_Value1((index + 1, [...errors, ...errors2])));
                    },
                    (a) {
                      if (runtime.isCancelled()) {
                        callback(_Value2(_Value1(())));
                        return;
                      }
                      callback(_Value2(_Value2(a)));
                    },
                    //
                  ),
                );
              } catch (error, st) {
                callback(_Value1((index + 1, [...errors, ContError(error, st)])));
              }
            },
            escape: (either) {
              switch (either) {
                case _Value1():
                  // cancellation
                  return;
                case _Value2(value: final either):
                  switch (either) {
                    case _Value1<List<ContError>, A>(value: final errors):
                      observer.onTerminate([...errors]);
                      return;
                    case _Value2<List<ContError>, A>(value: final a):
                      observer.onValue(a);
                      return;
                  }
              }
            },
            //
          );
        });
      case MergeWhenAllPolicy<A>(combine: final merge):
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
                      final safeCopyOfResultValue = merge(seedCopy, a);
                      seed = safeCopyOfResultValue;
                      seedCopy2 = safeCopyOfResultValue;
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
      case QuitFastPolicy<A>():
        return Cont.fromRun((runtime, observer) {
          final safeCopy = List<Cont<E, A>>.from(safeCopy0);
          if (safeCopy.isEmpty) {
            observer.onTerminate();
            return;
          }

          final List<List<ContError>> resultOfErrors = List.generate(safeCopy.length, (_) {
            return [];
          });

          bool isWinnerFound = false;
          int numberOfFinished = 0;

          final ContRuntime<E> sharedContRuntime = ContRuntime._(runtime.env(), () {
            return runtime.isCancelled() || isWinnerFound;
          });

          void handleTerminate(int index, List<ContError> errors) {
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
                    handleTerminate(i, [...errors]); // defensive copy
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
      _stackSafeLoop<_Either<(), _Either<(), _Either<A, List<ContError>>>>, (), _Either<(), _Either<A, List<ContError>>>>(
        seed: _Value1(()),
        keepRunningIf: (state) {
          switch (state) {
            case _Value1():
              // Keep running - need to execute the continuation again
              return _StackSafeLoopPolicyKeepRunning(());
            case _Value2(value: final result):
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
                    callback(_Value2(_Value1(())));
                    return;
                  }
                  // Terminated - stop the loop with errors
                  callback(_Value2(_Value2(_Value2([...errors]))));
                },
                (a) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(_Value1(())));
                    return;
                  }

                  try {
                    // Check the predicate
                    if (!predicate(a)) {
                      // Predicate satisfied - stop with success
                      callback(_Value2(_Value2(_Value1(a))));
                    } else {
                      // Predicate not satisfied - retry
                      callback(_Value1(()));
                    }
                  } catch (error, st) {
                    // Predicate threw an exception
                    callback(_Value2(_Value2(_Value2([ContError(error, st)]))));
                  }
                },
              ),
            );
          } catch (error, st) {
            callback(_Value2(_Value2(_Value2([ContError(error, st)]))));
          }
        },
        escape: (result) {
          switch (result) {
            case _Value1<(), _Either<A, List<ContError>>>():
              // cancellation
              return;
            case _Value2<(), _Either<A, List<ContError>>>(value: final result):
              switch (result) {
                case _Value1(value: final a):
                  observer.onValue(a);
                  return;
                case _Value2(value: final errors):
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
    return acquire.thenDo((resource) {
      return Cont.fromRun((runtime, observer) {
        // Create a non-cancellable runtime for the release phase
        // This ensures release always runs, even if the parent is cancelled
        final releaseRuntime = ContRuntime<E>._(runtime.env(), () => false);

        // Helper to safely call release and handle its result
        // Uses _Either to distinguish between success (value) and failure (errors)
        void doRelease(_Either<A, List<ContError>> useResult) {
          // Create helper to get release continuation safely
          Cont<E, ()> getReleaseCont() {
            try {
              return release(resource);
            } catch (error, st) {
              return Cont.terminate<E, ()>([ContError(error, st)]);
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
                    case _Value1<A, List<ContError>>():
                      // Use succeeded but release failed
                      observer.onTerminate([...releaseErrors]);
                    case _Value2<A, List<ContError>>(value: final useErrors):
                      // Both use and release failed - combine errors
                      final combinedErrors = [...useErrors, ...releaseErrors];
                      observer.onTerminate(combinedErrors);
                  }
                },
                // Release succeeded
                (_) {
                  switch (useResult) {
                    case _Value1<A, List<ContError>>(value: final value):
                      // Both use and release succeeded - return the value
                      observer.onValue(value);
                    case _Value2<A, List<ContError>>(value: final useErrors):
                      // Use failed but release succeeded - propagate use errors
                      observer.onTerminate(useErrors);
                  }
                },
              ),
            );
          } catch (error, st) {
            // Exception while setting up release
            switch (useResult) {
              case _Value1<A, List<ContError>>():
                // Use succeeded but release setup failed
                observer.onTerminate([ContError(error, st)]);
              case _Value2<A, List<ContError>>(value: final useErrors):
                // Both use and release setup failed
                final combinedErrors = [...useErrors, ContError(error, st)];
                observer.onTerminate(combinedErrors);
            }
          }
        }

        // Check cancellation before starting use phase
        if (runtime.isCancelled()) {
          // Still attempt to release the resource even if cancelled
          doRelease(_Value2(const []));
          return;
        }

        // Execute the use phase
        try {
          final useCont = use(resource);
          useCont._run(
            runtime,
            ContObserver._(
              // Use phase terminated
              (useErrors) {
                // Always release, even on termination
                doRelease(_Value2([...useErrors]));
              },
              // Use phase succeeded
              (value) {
                // Always release after successful use
                doRelease(_Value1(value));
              },
            ),
          );
        } catch (error, st) {
          // Exception while setting up use phase - still release
          doRelease(_Value2([ContError(error, st)]));
        }
      });
    });
  }
}

/// Extension providing flatten operation for nested continuations.
extension ContFlattenExtension<E, A> on Cont<E, Cont<E, A>> {
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
  void trap(E env, void Function(List<ContError>) onTerminate) {
    run(env, onTerminate, (_) {});
  }
}

/// Provides runtime context for continuation execution.
///
/// [ContRuntime] encapsulates the environment and cancellation state during
/// the execution of a [Cont]. It allows continuations to access contextual
/// information and check for cancellation.
final class ContRuntime<E> {
  final E _env;

  /// Function that checks whether the continuation execution has been cancelled.
  ///
  /// Returns `true` if the execution should be stopped, `false` otherwise.
  /// Continuations should check this regularly to support cooperative cancellation.
  final bool Function() isCancelled;

  const ContRuntime._(this._env, this.isCancelled);

  /// Returns the environment value of type [E].
  ///
  /// The environment provides contextual information such as configuration,
  /// dependencies, or any data that should flow through the continuation execution.
  E env() {
    return _env;
  }

  /// Creates a copy of this runtime with a different environment.
  ///
  /// Returns a new [ContRuntime] with the provided environment while preserving
  /// the cancellation function. This is used by [local] and related methods
  /// to modify the environment context.
  ///
  /// - [env]: The new environment value to use.
  ContRuntime<E2> copyUpdateEnv<E2>(E2 env) {
    return ContRuntime._(env, isCancelled);
  }
}

/// An observer that handles both success and termination cases of a continuation.
///
/// [ContObserver] provides the callback mechanism for receiving results from
/// a [Cont] execution. It encapsulates handlers for both successful values
/// and termination (failure) scenarios.
final class ContObserver<A> {
  final void Function(List<ContError> errors) _onTerminate;

  /// The callback function invoked when the continuation produces a successful value.
  final void Function(A value) onValue;

  /// Creates an observer with termination and value handlers.
  ///
  /// - [_onTerminate]: Handler called when the continuation terminates (fails).
  /// - [onValue]: Handler called when the continuation produces a successful value.
  const ContObserver._(this._onTerminate, this.onValue);

  /// Invokes the termination callback with the provided errors.
  ///
  /// - [errors]: List of errors that caused termination. Defaults to an empty list.
  void onTerminate([List<ContError> errors = const []]) {
    _onTerminate(errors);
  }

  /// Creates a new observer with an updated termination handler.
  ///
  /// Returns a copy of this observer with a different termination callback,
  /// while preserving the value callback.
  ///
  /// - [onTerminate]: The new termination handler to use.
  ContObserver<A> copyUpdateOnTerminate(void Function(List<ContError> errors) onTerminate) {
    return ContObserver._(onTerminate, onValue);
  }

  /// Creates a new observer with an updated value handler and potentially different type.
  ///
  /// Returns a copy of this observer with a different value callback type,
  /// while preserving the termination callback.
  ///
  /// - [onValue]: The new value handler to use.
  ContObserver<A2> copyUpdateOnValue<A2>(void Function(A2 value) onValue) {
    return ContObserver._(onTerminate, onValue);
  }
}

// private tools and helpers

void _stackSafeLoop<A, B, C>({
  required A seed,
  required _StackSafeLoopPolicy<B, C> Function(A) keepRunningIf,
  required void Function(B, void Function(A)) computation,
  required void Function(C) escape,
  //
}) {
  var mutableSeedCopy = seed;

  while (true) {
    final policy = keepRunningIf(mutableSeedCopy);

    switch (policy) {
      case _StackSafeLoopPolicyStop<B, C>(value: final value):
        escape(value);
        return;
      case _StackSafeLoopPolicyKeepRunning<B, C>():
        break;
    }

    bool isSchedulerUsed = false;
    bool isSync1 = true;
    bool isSync2 = false;

    computation(policy.value, (updatedA) {
      if (isSchedulerUsed) {
        return;
      }

      isSchedulerUsed = true;

      if (isSync1) {
        isSync2 = true;
        mutableSeedCopy = updatedA;
        return;
      }
      // not sync

      _stackSafeLoop(
        seed: updatedA,
        keepRunningIf: keepRunningIf,
        computation: computation,
        escape: escape,
        //
      );
    });
    isSync1 = false;
    if (isSync2) {
      continue;
    } else {
      break;
    }
  }
}

sealed class _Either<A, B> {
  const _Either();
}

final class _Value1<A, B> extends _Either<A, B> {
  final A value;

  const _Value1(this.value);
}

final class _Value2<A, B> extends _Either<A, B> {
  final B value;

  const _Value2(this.value);
}

sealed class _StackSafeLoopPolicy<A, B> {
  const _StackSafeLoopPolicy();
}

final class _StackSafeLoopPolicyKeepRunning<A, B> extends _StackSafeLoopPolicy<A, B> {
  final A value;

  const _StackSafeLoopPolicyKeepRunning(this.value);
}

final class _StackSafeLoopPolicyStop<A, B> extends _StackSafeLoopPolicy<A, B> {
  final B value;

  const _StackSafeLoopPolicyStop(this.value);
}

// runs ALL computations till the end
Cont<E, A3> _both<E, A1, A2, A3>(
  Cont<E, A1> left,
  Cont<E, A2> right,
  A3 Function(A1 a, A2 a2) combine,
  List<ContError> Function(List<ContError> acc, List<ContError> value) combine2,
  //
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneFailed = false;
    bool isOneValue = false;

    bool isLeftFailedFirst = false;

    A1? outerA1;
    A2? outerA2;

    final List<ContError> leftErrors = [];
    final List<ContError> rightErrors = [];

    void handleValue(_Either<A1, A2> either) {
      if (runtime.isCancelled()) {
        return;
      }

      switch (either) {
        case _Value1<A1, A2>(value: final a1):
          outerA1 = a1;
        case _Value2<A1, A2>(value: final a2):
          outerA2 = a2;
      }

      if (isOneFailed) {
        observer.onTerminate(leftErrors + rightErrors);
        return;
      }

      if (!isOneValue) {
        isOneValue = true;
        return;
      }

      try {
        final c = combine(outerA1 as A1, outerA2 as A2);
        observer.onValue(c);
      } catch (error, st) {
        observer.onTerminate([ContError(error, st)]);
      }
    }

    void handleTerminate(bool isLeft, List<ContError> errors) {
      if (runtime.isCancelled()) {
        return;
      }

      if (isOneValue) {
        if (isLeft) {
          leftErrors.addAll(errors);
        } else {
          rightErrors.addAll(errors);
        }

        observer.onTerminate(leftErrors + rightErrors);
        return;
      }

      if (isOneFailed) {
        // check the policy and decide what to do with both error lists
        if (isLeft) {
          leftErrors.addAll(errors);
        } else {
          rightErrors.addAll(errors);
        }

        final List<ContError> firstErrors;
        final List<ContError> secondErrors;

        if (isLeftFailedFirst) {
          firstErrors = leftErrors;
          secondErrors = rightErrors;
        } else {
          firstErrors = rightErrors;
          secondErrors = leftErrors;
        }

        observer.onTerminate(combine2(firstErrors, secondErrors));
        return;
      }

      isOneFailed = true;
      if (isLeft) {
        isLeftFailedFirst = true;
        leftErrors.addAll(errors);
      } else {
        isLeftFailedFirst = false;
        rightErrors.addAll(errors);
      }
    }

    try {
      left._run(
        runtime,
        ContObserver._(
          (errors) {
            handleTerminate(true, [...errors]);
          },
          (a) {
            handleValue(_Value1(a));
          },
        ),
      );
    } catch (error, st) {
      handleTerminate(true, [ContError(error, st)]);
    }

    try {
      right._run(
        runtime,
        ContObserver._(
          (errors) {
            handleTerminate(false, [...errors]);
          },
          (a2) {
            handleValue(_Value2(a2));
          },
        ),
      );
    } catch (error, st) {
      handleTerminate(false, [ContError(error, st)]);
    }
  });
}

// runs ALL computations till the end
Cont<E, A> _either<E, A>(
  Cont<E, A> left,
  Cont<E, A> right,
  List<ContError> Function(List<ContError> left, List<ContError> right) combine,
  A Function(A acc, A value) combine2,
  //
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneSuccess = false;
    bool isOneTerminate = false;

    bool isLeftSucceededFirst = false;

    List<ContError>? outerLeft;
    List<ContError>? outerRight;

    A? leftVal;
    A? rightVal;

    void handleValue(bool isLeft, A value) {
      if (isOneTerminate) {
        if (isLeft) {
          leftVal = value;
          observer.onValue(value);
        } else {
          rightVal = value;
          observer.onValue(value);
        }

        return;
      }

      if (isOneSuccess) {
        // check the policy and decide what to do with both error lists
        if (isLeft) {
          leftVal = value;
        } else {
          rightVal = value;
        }

        final A firstValue;
        final A secondValue;

        if (isLeftSucceededFirst) {
          firstValue = leftVal as A;
          secondValue = rightVal as A;
        } else {
          firstValue = rightVal as A;
          secondValue = leftVal as A;
        }

        observer.onValue(combine2(firstValue, secondValue));
        return;
      }

      isOneSuccess = true;
      if (isLeft) {
        isLeftSucceededFirst = true;
        leftVal = value;
      } else {
        isLeftSucceededFirst = false;
        rightVal = value;
      }
    }

    void handleTerminate(bool isLeft) {
      if (isOneSuccess) {
        if (isLeft) {
          observer.onValue(rightVal as A);
        } else {
          observer.onValue(leftVal as A);
        }
        return;
      }

      if (!isOneTerminate) {
        isOneTerminate = true;
        return;
      }

      try {
        final result = combine(outerLeft!, outerRight!);
        observer.onTerminate([...result]);
      } catch (error, st) {
        observer.onTerminate([ContError(error, st)]);
      }
    }

    try {
      left._run(
        runtime,
        ContObserver._(
          (errors) {
            if (runtime.isCancelled()) {
              return;
            }
            // strict order must be followed
            outerLeft = [...errors];
            handleTerminate(true);
          },
          (a1) {
            if (runtime.isCancelled()) {
              return;
            }
            handleValue(true, a1);
          },
        ),
      );
    } catch (error, st) {
      outerLeft = [ContError(error, st)];
      handleTerminate(true);
    }

    try {
      right._run(
        runtime,
        ContObserver._(
          (errors) {
            if (runtime.isCancelled()) {
              return;
            }
            // strict order must be followed
            outerRight = [...errors];
            handleTerminate(false);
          },
          (a2) {
            if (runtime.isCancelled()) {
              return;
            }
            handleValue(false, a2);
          },
        ),
      );
    } catch (error, st) {
      outerRight = [ContError(error, st)];
      handleTerminate(false);
    }
  });
}
