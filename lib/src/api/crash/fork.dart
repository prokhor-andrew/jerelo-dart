part of '../../cont.dart';

/// Implementation of the fire-and-forget fork on the crash path.
///
/// Runs [cont], and on crash starts the side-effect continuation
/// produced by [f] without waiting for it. The original crash
/// is forwarded to the observer immediately. Outcomes from the side-effect
/// are dispatched to the provided callbacks: [onPanic] (defaults to
/// rethrowing), [onCrash], [onElse], and [onThen] (all default to ignoring).
Cont<E, F, A> _crashFork<E, F, F2, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F2, A2> Function(ContCrash crash) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
}) {
  return Cont.fromRun((runtime, observer) {
    cont.runWith(
      runtime,
      observer.copyUpdateOnCrash((crash) {
        if (runtime.isCancelled()) {
          return;
        }

        // if this crashes, it should crash the computation
        final Cont<E, F2, A2> contA2;
        try {
          contA2 = f(crash).absurdify();
        } catch (_) {
          observer.onCrash(crash);
          return;
        }

        try {
          contA2.run(
            runtime.env(),
            onPanic: onPanic,
            onCrash: onCrash,
            onElse: onElse,
            onThen: onThen,
          );
        } catch (_) {
          // do nothing, if anything happens to side-effect, it's not
          // a concern of the crashFork
        }

        observer.onCrash(crash);
      }),
    );
  });
}

extension ContCrashForkExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on crash in a fire-and-forget manner.
  ///
  /// If the continuation crashes, starts the side-effect continuation without waiting
  /// for it to complete. Unlike [crashTap], this does not wait for the side-effect to
  /// finish before propagating the crash.
  ///
  /// Outcomes from the forked continuation are dispatched to optional callbacks:
  /// - [onPanic]: Called when the side-effect triggers a panic. Defaults to rethrowing.
  /// - [onCrash]: Called when the side-effect crashes. Defaults to ignoring.
  /// - [onElse]: Called when the side-effect terminates with an error. Defaults to ignoring.
  /// - [onThen]: Called when the side-effect succeeds. Defaults to ignoring.
  ///
  /// - [f]: Function that returns a side-effect continuation.
  Cont<E, F, A> crashFork<F2, A2>(
    Cont<E, F2, A2> Function(ContCrash crash) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return _crashFork(
      this,
      f,
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }

  /// Executes a zero-argument side-effect continuation on crash in a fire-and-forget manner.
  ///
  /// Similar to [crashFork] but ignores the crash information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> crashFork0<F2, A2>(
    Cont<E, F2, A2> Function() f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return crashFork(
      (_) {
        return f();
      },
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }

  /// Executes a side-effect continuation on crash in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [crashFork], but the side-effect function receives both the crash
  /// and the environment. The side-effect is started without waiting for it to complete.
  /// Outcomes are dispatched to the optional [onPanic], [onCrash], [onElse], and
  /// [onThen] callbacks.
  ///
  /// - [f]: Function that takes the environment and crash, and returns a side-effect continuation.
  Cont<E, F, A> crashForkWithEnv<F2, A2>(
    Cont<E, F2, A2> Function(E env, ContCrash crash) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashFork<F2, A2>(
        (crash) {
          return f(e, crash);
        },
        onPanic: onPanic,
        onCrash: onCrash,
        onElse: onElse,
        onThen: onThen,
      );
    });
  }

  /// Executes a side-effect continuation on crash in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [crashForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the crash information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> crashForkWithEnv0<F2, A2>(
    Cont<E, F2, A2> Function(E env) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return crashForkWithEnv(
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
