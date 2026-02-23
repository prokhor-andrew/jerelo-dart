part of '../../cont.dart';

/// Implementation of the fire-and-forget fork on the crash path.
///
/// Runs [cont], and on crash starts the side-effect continuation
/// produced by [f] without waiting for it. The original crash
/// is forwarded to the observer immediately. Results from the side-effect
/// are silently ignored.
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
        } catch (error, st) {
          observer.onCrash(NormalCrash._(error, st));
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
  /// finish before propagating the crash. Any results from the side-effect are
  /// silently ignored.
  ///
  /// - [f]: Function that returns a side-effect continuation.
  Cont<E, F, A> crashFork<F2, A2>(
    Cont<E, F2, A2> Function(ContCrash crash) f,
  ) {
    return _crashFork(this, f);
  }

  /// Executes a zero-argument side-effect continuation on crash in a fire-and-forget manner.
  ///
  /// Similar to [crashFork] but ignores the crash information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> crashFork0<F2, A2>(
    Cont<E, F2, A2> Function() f,
  ) {
    return crashFork((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on crash in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [crashFork], but the side-effect function receives both the crash
  /// and the environment. The side-effect is started without waiting for it to complete,
  /// and any results from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the environment and crash, and returns a side-effect continuation.
  Cont<E, F, A> crashForkWithEnv<F2, A2>(
    Cont<E, F2, A2> Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashFork<F2, A2>((crash) {
        return f(e, crash);
      });
    });
  }

  /// Executes a side-effect continuation on crash in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [crashForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the crash information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> crashForkWithEnv0<F2, A2>(
    Cont<E, F2, A2> Function(E env) f,
  ) {
    return crashForkWithEnv((e, _) {
      return f(e);
    });
  }
}
