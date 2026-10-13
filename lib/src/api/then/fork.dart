import 'package:jerelo/jerelo.dart';

/// Implementation of the fire-and-forget fork on the success path.
///
/// Runs [cont], and on success starts the side-effect continuation produced
/// by [f] without waiting for it, then forwards the original value to the
/// observer. A synchronous side-effect runs to completion before the value
/// is forwarded; an asynchronous one does not delay it. Outcomes from the
/// side-effect are dispatched to the provided callbacks: [onPanic] (defaults
/// to rethrowing), [onCrash], [onElse], and [onThen] (all default to
/// ignoring).
Cont<E, F, A> _thenFork<E, F, F2, A, A2>(
  Cont<E, F, A> cont,
  Cont<E, F2, A2> Function(A a) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
}) {
  return Cont.fromRun((env, observer) {
    return cont.runWith(
      env,
      observer.copyUpdateOnThen((a) {
        // if this crashes, it should crash the computation
        ContCrash.tryCatch(() {
          final contA2 = f(a);
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
            // a concern of the thenFork
          }
        })._ifCrash(observer.onCrash);

        observer.onThen(a);
      }),
    );
  });
}

extension ContThenForkExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation in a fire-and-forget manner.
  ///
  /// Unlike [thenTap], this method does not wait for the side-effect to complete.
  /// The side-effect continuation is started before the original value is
  /// forwarded: a synchronous side-effect runs to completion first, while an
  /// asynchronous one does not delay the value. If [f] itself throws, the
  /// computation crashes.
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
  /// value and the environment. The side-effect is started without waiting for it to complete.
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

/// Runs [onCrash] when the computation threw.
extension _CrashOrIfCrash<T> on CrashOr<T> {
  void _ifCrash(void Function(NormalCrash crash) onCrash) {
    if (this case CrashCrashOr(crash: final crash)) {
      onCrash(crash);
    }
  }
}
