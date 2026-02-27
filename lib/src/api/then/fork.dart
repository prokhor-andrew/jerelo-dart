part of '../../cont.dart';

/// Implementation of the fire-and-forget fork on the success path.
///
/// Runs [cont], and on success starts the side-effect continuation produced
/// by [f] without waiting for it. The original value is forwarded to the
/// observer immediately. Outcomes from the side-effect are dispatched to
/// the provided callbacks: [onPanic] (defaults to rethrowing), [onCrash],
/// [onElse], and [onThen] (all default to ignoring).
Cont<E, F, A> _thenFork<E, F, F2, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F2, A2> Function(A a) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
}) {
  return Cont.fromRun((runtime, observer) {
    cont.runWith(
      runtime,
      observer.copyUpdateOnThen((a) {
        if (runtime.isCancelled()) {
          return;
        }

        // if this crashes, it should crash the computation
        ContCrash.tryCatch(() {
          final contA2 = f(a).absurdify();
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
            // a concern of the thenFork
          }
        }).match((_) {}, observer.onCrash);

        observer.onThen(a);
      }),
    );
  });
}

extension ContThenForkExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation in a fire-and-forget manner.
  ///
  /// Unlike [thenTap], this method does not wait for the side-effect to complete.
  /// The side-effect continuation is started immediately, and the original value
  /// is returned without delay.
  ///
  /// Outcomes from the forked continuation are dispatched to optional callbacks:
  /// - [onPanic]: Called when the side-effect triggers a panic. Defaults to rethrowing.
  /// - [onCrash]: Called when the side-effect crashes. Defaults to ignoring.
  /// - [onElse]: Called when the side-effect terminates with an error. Defaults to ignoring.
  /// - [onThen]: Called when the side-effect succeeds. Defaults to ignoring.
  ///
  /// - [f]: Function that takes the current value and returns a side-effect continuation.
  Cont<E, F, A> thenFork<F2, A2>(
    Cont<E, F2, A2> Function(A a) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return _thenFork(
      this,
      f,
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }

  /// Executes a zero-argument side-effect continuation in a fire-and-forget manner.
  ///
  /// Similar to [thenFork] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> thenFork0<F2, A2>(
    Cont<E, F2, A2> Function() f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return thenFork(
      (_) {
        return f();
      },
      onPanic: onPanic,
      onCrash: onCrash,
      onElse: onElse,
      onThen: onThen,
    );
  }

  /// Executes a side-effect continuation in a fire-and-forget manner with access to the environment.
  ///
  /// Similar to [thenFork], but the side-effect function receives both the current
  /// value and the environment. The side-effect is started immediately without waiting.
  /// Outcomes are dispatched to the optional [onPanic], [onCrash], [onElse], and
  /// [onThen] callbacks.
  ///
  /// - [f]: Function that takes the environment and value, and returns a side-effect continuation.
  Cont<E, F, A> thenForkWithEnv<F2, A2>(
    Cont<E, F2, A2> Function(E env, A a) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return Cont.askThen<E, F>().thenDo(
      (e) {
        return thenFork(
          (a) {
            return f(e, a);
          },
          onPanic: onPanic,
          onCrash: onCrash,
          onElse: onElse,
          onThen: onThen,
        );
      },
    );
  }

  /// Executes a side-effect continuation in a fire-and-forget manner with access to the environment only.
  ///
  /// Similar to [thenForkWithEnv], but the side-effect function only receives
  /// the environment and ignores the current value.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> thenForkWithEnv0<F2, A2>(
    Cont<E, F2, A2> Function(E env) f, {
    void Function(NormalCrash crash) onPanic = _panic,
    void Function(ContCrash crash) onCrash = _ignore,
    void Function(F2 error) onElse = _ignore,
    void Function(A2 value) onThen = _ignore,
  }) {
    return thenForkWithEnv(
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
