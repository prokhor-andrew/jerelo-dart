import 'package:jerelo/jerelo.dart';

Cont<E, F, A> _crashTap<E, F, A>(
  Cont<E, F, A> cont,
  Cont<E, F, A> Function(ContCrash crash) f,
) {
  return cont.crashDo((crash) {
    final Cont<E, F, A> cont2;
    try {
      cont2 = f(crash).absurdify();
    } catch (_, __) {
      return Cont.crash(crash);
    }
    return cont2.crashDo((_) {
      return Cont.crash(crash);
    });
  });
}

extension ContCrashTapExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on crash.
  ///
  /// If the continuation crashes, executes the side-effect continuation for its effects.
  /// The behavior depends on the side-effect's outcome:
  ///
  /// - If the side-effect crashes: Returns the original crash (ignoring side-effect crash).
  /// - If the side-effect succeeds: Returns the side-effect's success value, effectively
  ///   recovering from the original crash.
  /// - If the side-effect terminates: Propagates the termination as-is.
  ///
  /// This means the operation can recover from a crash if the side-effect succeeds.
  /// If you want to always propagate the original crash regardless of the side-effect's
  /// outcome, use [crashFork] instead.
  ///
  /// - [f]: Function that receives the original crash and returns a side-effect continuation.
  Cont<E, F, A> crashTap(
    Cont<E, F, A> Function(ContCrash crash) f,
  ) {
    return _crashTap(this, f);
  }

  /// Executes a zero-argument side-effect continuation on crash.
  ///
  /// Similar to [crashTap] but ignores the crash information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> crashTap0(Cont<E, F, A> Function() f) {
    return crashTap((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on crash with access to the environment.
  ///
  /// Similar to [crashTap], but the side-effect function receives both the crash
  /// and the environment. This allows crash-handling side-effects (like logging or
  /// reporting) to access configuration or context information.
  ///
  /// - [f]: Function that takes the environment and crash, and returns a side-effect continuation.
  Cont<E, F, A> crashTapWithEnv(
    Cont<E, F, A> Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashTap((crash) {
        return f(e, crash);
      });
    });
  }

  /// Executes a side-effect continuation on crash with access to the environment only.
  ///
  /// Similar to [crashTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the crash information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> crashTapWithEnv0(
    Cont<E, F, A> Function(E env) f,
  ) {
    return crashTapWithEnv((e, _) {
      return f(e);
    });
  }
}
