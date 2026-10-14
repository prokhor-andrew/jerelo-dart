part of '../../cont.dart';

extension ContCrashWhileExtension<E, F, A>
    on Cont<E, F, A> {
  /// Repeatedly retries the continuation while the predicate returns `true` on crash.
  ///
  /// If the continuation crashes, tests the crash with the predicate. The loop
  /// continues retrying as long as the predicate returns `true`, and stops when the
  /// predicate returns `false` (propagating the crash) or when the continuation
  /// succeeds or terminates.
  ///
  /// The loop is stack-safe and handles asynchronous continuations correctly.
  /// If the predicate throws, the loop stops and crashes with that exception
  /// instead of the original crash.
  ///
  /// A cancel is forwarded to the running attempt, and no attempt starts
  /// after it: the loop ends with the outcome of the attempt that was
  /// running, once it reports, without calling [predicate].
  ///
  /// This is useful for retry logic with crash-based conditions, such as retrying
  /// while specific transient crashes occur.
  ///
  /// - [predicate]: Function that tests the crash. Returns `true` to retry,
  ///   or `false` to stop and propagate the crash.
  Cont<E, F, A> crashWhile(
    bool Function(ContCrash crash) predicate,
  ) {
    return Cont._tailRecM<E, F, (), A>((), (
      _,
      isCancelled,
    ) {
      return thenMap<_TailRec<(), A>>(_DoneTailRec.new)
          .crashDo((crash) {
        // after a cancel, end with the crash instead of
        // starting another attempt
        return !isCancelled() && predicate(crash)
            ? Cont.of(_NextTailRec(()))
            : Cont.crash(crash);
      });
    });
  }

  /// Repeatedly retries while a zero-argument predicate returns `true`.
  ///
  /// Similar to [crashWhile] but the predicate doesn't examine the crash.
  ///
  /// - [predicate]: Zero-argument function that determines whether to retry.
  Cont<E, F, A> crashWhile0(bool Function() predicate) {
    return crashWhile((_) {
      return predicate();
    });
  }

  /// Repeatedly retries with access to both crash and environment.
  ///
  /// Similar to [crashWhile], but the predicate function receives both the
  /// crash and the environment. This is useful when retry logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and crash, and determines whether to retry.
  Cont<E, F, A> crashWhileWithEnv(
    bool Function(E env, ContCrash crash) predicate,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashWhile((crash) {
        return predicate(e, crash);
      });
    });
  }

  /// Repeatedly retries with access to the environment only.
  ///
  /// Similar to [crashWhileWithEnv], but the predicate only receives the
  /// environment and ignores the crash.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to retry.
  Cont<E, F, A> crashWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return crashWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
