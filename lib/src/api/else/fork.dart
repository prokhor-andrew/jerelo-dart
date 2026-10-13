import 'package:jerelo/jerelo.dart';

/// Implementation of the fire-and-forget fork on the termination path.
///
/// Runs [cont], and on termination starts the side-effect continuation
/// produced by [f] without waiting for it, then forwards the original
/// termination error to the observer. A synchronous side-effect runs to
/// completion before the error is forwarded; an asynchronous one does not
/// delay it. Outcomes from the side-effect are dispatched to the provided
/// callbacks: [onPanic] (defaults to rethrowing), [onCrash], [onElse], and
/// [onThen] (all default to ignoring).
Cont<E, F, A> _elseFork<E, F, F2, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F2, A2> Function(F error) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
}) {
  return Cont.fromRun((env, observer) {
    return cont.runWith(
      env,
      observer.copyUpdateOnElse((error) {
        // if this crashes, it should crash the computation
        final result = ContCrash.tryCatch(() {
          final contA2 = f(error);
          try {
            contA2.run(
              env,
              onPanic: onPanic,
              onCrash: onCrash,
              onElse: onElse,
              onThen: onThen,
            );
          } catch (_) {
            // do nothing, if anything happens to side-effect, it's not
            // a concern of the elseFork
          }
        });
        switch (result) {
          case ValueCrashOr():
            observer.onElse(error);
          case CrashCrashOr(crash: final crash):
            observer.onCrash(crash);
        }
      }),
    );
  });
}

extension ContElseForkExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// If the continuation terminates, starts the side-effect continuation without waiting
  /// for it to complete. Unlike [elseTap], this does not wait for the side-effect to
  /// finish before propagating the termination. A synchronous side-effect still runs
  /// to completion before the error is forwarded. If [f] itself throws, the
  /// computation crashes.
  ///
  /// The side-effect is detached: cancelling the computation does not cancel
  /// it. The main computation is cancelled as usual.
  ///
  /// Outcomes from the forked continuation are dispatched to optional callbacks:
  /// - [onPanic]: Called when the side-effect triggers a panic. Defaults to
  ///   rethrowing it in a microtask.
  /// - [onCrash]: Called when the side-effect crashes. Defaults to ignoring.
  /// - [onElse]: Called when the side-effect terminates with an error. Defaults to ignoring.
  /// - [onThen]: Called when the side-effect succeeds. Defaults to ignoring.
  ///
  /// - [f]: Function that returns a side-effect continuation.
  Cont<E, F, A> elseFork<F2, A2>(
    Cont<E, F2, A2> Function(F error) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return _elseFork(
      this,
      f,
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }

  /// Executes a zero-argument side-effect continuation on termination in a fire-and-forget manner.
  ///
  /// Similar to [elseFork] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> elseFork0<F2, A2>(
    Cont<E, F2, A2> Function() f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return elseFork(
      (_) {
        return f();
      },
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [elseFork], but the side-effect function receives both the error
  /// and the environment. The side-effect is started without waiting for it to complete.
  /// Outcomes are dispatched to the optional [onPanic], [onCrash], [onElse], and
  /// [onThen] callbacks.
  ///
  /// - [f]: Function that takes the environment and error, and returns a side-effect continuation.
  Cont<E, F, A> elseForkWithEnv<F2, A2>(
    Cont<E, F2, A2> Function(E env, F error) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return Cont.askThen<E, F>().thenDo((e) {
      return elseFork<F2, A2>(
        (error) {
          return f(e, error);
        },
        onPanic: onPanic,
        onCrash: onCrash,
        onElse: onElse,
        onThen: onThen,
      );
    });
  }

  /// Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [elseForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> elseForkWithEnv0<F2, A2>(
    Cont<E, F2, A2> Function(E env) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return elseForkWithEnv(
      (e, _) {
        return f(e);
      },
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }
}

/// Default panic handler: rethrows the panic in a microtask, so it surfaces
/// as an unhandled error in the current zone. Same as jerelo's default.
void _panic(NormalCrash crash) {
  Future.microtask(() {
    Error.throwWithStackTrace(
      crash.error,
      crash.stackTrace,
    );
  });
}

/// Default handler that ignores the value it receives.
void _ignore(Object? value) {}
