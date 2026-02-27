import 'package:jerelo/jerelo.dart';

extension ContCrashUntilExtension<E, F, A>
    on Cont<E, F, A> {
  /// Repeatedly retries the continuation until the predicate returns `true` on crash.
  ///
  /// If the continuation crashes, tests the crash with the predicate. The loop
  /// continues retrying while the predicate returns `false`, and stops when the
  /// predicate returns `true` (propagating the crash) or when the continuation
  /// succeeds or terminates.
  ///
  /// This is the inverse of [crashWhile] - implemented as `crashWhile((crash) => !predicate(crash))`.
  /// Use this when you want to retry until a specific crash condition is met.
  ///
  /// - [predicate]: Function that tests the crash. Returns `true` to stop
  ///   and propagate the crash, or `false` to continue retrying.
  Cont<E, F, A> crashUntil(
    bool Function(ContCrash crash) predicate,
  ) {
    return crashWhile((crash) {
      return !predicate(crash);
    });
  }

  /// Repeatedly retries until a zero-argument predicate returns `true`.
  ///
  /// Similar to [crashUntil] but the predicate doesn't examine the crash.
  ///
  /// - [predicate]: Zero-argument function that determines when to stop retrying.
  Cont<E, F, A> crashUntil0(bool Function() predicate) {
    return crashUntil((_) {
      return predicate();
    });
  }

  /// Repeatedly retries with access to both crash and environment.
  ///
  /// Similar to [crashUntil], but the predicate function receives both the
  /// crash and the environment. This is useful when retry logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and crash, and determines when to stop.
  Cont<E, F, A> crashUntilWithEnv(
    bool Function(E env, ContCrash crash) predicate,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashUntil((crash) {
        return predicate(e, crash);
      });
    });
  }

  /// Repeatedly retries with access to the environment only.
  ///
  /// Similar to [crashUntilWithEnv], but the predicate only receives the
  /// environment and ignores the crash.
  ///
  /// - [predicate]: Function that takes the environment and determines when to stop.
  Cont<E, F, A> crashUntilWithEnv0(
    bool Function(E env) predicate,
  ) {
    return crashUntilWithEnv((e, _) {
      return predicate(e);
    });
  }
}
