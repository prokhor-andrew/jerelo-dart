import 'package:jerelo/jerelo.dart';

extension ContCrashUnlessExtension<E, F, A>
    on Cont<E, F, A> {
  /// Conditionally recovers from a crash when the predicate is not satisfied.
  ///
  /// Filters crashes based on the predicate. If the predicate returns
  /// `true`, the continuation continues crashing with the original crash.
  /// If the predicate returns `false`, the continuation recovers with the
  /// provided fallback value.
  ///
  /// - [predicate]: Function that tests the crash.
  /// - [fallback]: The value to recover with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessThen(
    bool Function(ContCrash crash) predicate, {
    required A fallback,
  }) {
    return crashDo((crash) {
      if (predicate(crash)) {
        return Cont.crash(crash);
      }

      return Cont.of(fallback);
    });
  }

  /// Conditionally recovers based on a zero-argument predicate.
  ///
  /// Similar to [crashUnlessThen] but the predicate doesn't examine the crash.
  ///
  /// - [predicate]: Zero-argument function that determines whether to keep crashing.
  /// - [fallback]: The value to recover with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessThen0(
    bool Function() predicate, {
    required A fallback,
  }) {
    return crashUnlessThen((_) {
      return predicate();
    }, fallback: fallback);
  }

  /// Conditionally recovers with access to both crash and environment.
  ///
  /// Similar to [crashUnlessThen], but the predicate function receives both the
  /// crash and the environment. This is useful when recovery logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and crash, and determines whether to keep crashing.
  /// - [fallback]: The value to recover with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessThenWithEnv(
    bool Function(E env, ContCrash crash) predicate, {
    required A fallback,
  }) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashUnlessThen((crash) {
        return predicate(e, crash);
      }, fallback: fallback);
    });
  }

  /// Conditionally recovers with access to the environment only.
  ///
  /// Similar to [crashUnlessThenWithEnv], but the predicate only receives the
  /// environment and ignores the crash.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to keep crashing.
  /// - [fallback]: The value to recover with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessThenWithEnv0(
    bool Function(E env) predicate, {
    required A fallback,
  }) {
    return crashUnlessThenWithEnv((e, _) {
      return predicate(e);
    }, fallback: fallback);
  }

  /// Conditionally recovers from a crash to an error when the predicate is not satisfied.
  ///
  /// Filters crashes based on the predicate. If the predicate returns
  /// `true`, the continuation continues crashing with the original crash.
  /// If the predicate returns `false`, the continuation terminates with the
  /// provided fallback error.
  ///
  /// - [predicate]: Function that tests the crash.
  /// - [fallback]: The error to terminate with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessElse(
    bool Function(ContCrash crash) predicate, {
    required F fallback,
  }) {
    return crashDo((crash) {
      if (predicate(crash)) {
        return Cont.crash(crash);
      }

      return Cont.error(fallback);
    });
  }

  /// Conditionally recovers to an error based on a zero-argument predicate.
  ///
  /// Similar to [crashUnlessElse] but the predicate doesn't examine the crash.
  ///
  /// - [predicate]: Zero-argument function that determines whether to keep crashing.
  /// - [fallback]: The error to terminate with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessElse0(
    bool Function() predicate, {
    required F fallback,
  }) {
    return crashUnlessElse((_) {
      return predicate();
    }, fallback: fallback);
  }

  /// Conditionally recovers to an error with access to both crash and environment.
  ///
  /// Similar to [crashUnlessElse], but the predicate function receives both the
  /// crash and the environment. This is useful when recovery logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and crash, and determines whether to keep crashing.
  /// - [fallback]: The error to terminate with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessElseWithEnv(
    bool Function(E env, ContCrash crash) predicate, {
    required F fallback,
  }) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashUnlessElse((crash) {
        return predicate(e, crash);
      }, fallback: fallback);
    });
  }

  /// Conditionally recovers to an error with access to the environment only.
  ///
  /// Similar to [crashUnlessElseWithEnv], but the predicate only receives the
  /// environment and ignores the crash.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to keep crashing.
  /// - [fallback]: The error to terminate with when the predicate returns `false`.
  Cont<E, F, A> crashUnlessElseWithEnv0(
    bool Function(E env) predicate, {
    required F fallback,
  }) {
    return crashUnlessElseWithEnv((e, _) {
      return predicate(e);
    }, fallback: fallback);
  }
}
