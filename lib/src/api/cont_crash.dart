part of '../cont.dart';

/// Base class for all crash values in the continuation monad.
///
/// A crash represents an unexpected exception that escaped from inside a
/// computation — the equivalent of an unhandled exception in traditional code.
/// Unlike business-logic errors on the else channel (type [F]), crashes are
/// untyped and carry the raw [Object] and [StackTrace].
///
/// [ContCrash] is a sealed class with three subtypes:
/// - [NormalCrash]: a single caught exception.
/// - [MergedCrash]: two crashes combined from parallel or sequential operations.
/// - [CollectedCrash]: multiple crashes collected from a list of operations.
sealed class ContCrash {
  const ContCrash();

  /// Runs [function] and wraps the outcome in a [CrashOr].
  ///
  /// If [function] completes without throwing, returns a [CrashOr] carrying
  /// the computed value. If [function] throws, returns a [CrashOr] carrying
  /// the caught exception as a [NormalCrash].
  /// This helper is used internally to convert raw Dart exceptions into
  /// the [ContCrash] representation.
  static CrashOr<T> tryCatch<T>(T Function() function) {
    try {
      final value = function();
      return _ValueCrashOr(value);
    } catch (error, st) {
      return _CrashCrashOr(NormalCrash._(error, st));
    }
  }
}

/// A crash that wraps a single exception thrown during computation.
final class NormalCrash extends ContCrash {
  /// The exception object that caused the crash.
  final Object error;

  /// The stack trace captured at the point the exception was thrown.
  final StackTrace stackTrace;

  const NormalCrash._(this.error, this.stackTrace);

  @override
  String toString() {
    return "NormalCrash { error=$error, stackTrace=$stackTrace }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! NormalCrash) {
      return false;
    }

    return error == other.error;
  }

  @override
  int get hashCode => error.hashCode;
}

/// A crash that combines two crashes from paired operations.
///
/// Produced when two continuations are run (e.g. in [Cont.coalesce]) and both
/// crash. Carries the original [left] and [right] crashes so callers can
/// inspect both.
final class MergedCrash extends ContCrash {
  /// The crash from the left (or first) operation.
  final ContCrash left;

  /// The crash from the right (or second) operation.
  final ContCrash right;

  const MergedCrash._(this.left, this.right);

  @override
  String toString() {
    return "MergedCrash { left=$left, right=$right }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! MergedCrash) {
      return false;
    }

    return left == other.left && right == other.right;
  }

  @override
  int get hashCode => left.hashCode ^ right.hashCode;
}

/// A crash that collects multiple crashes from a list of operations.
///
/// Produced when [Cont.converge] is run with [RunAllCrashPolicy] and more
/// than one continuation crashes. The [crashes] map associates each
/// continuation's index with its [ContCrash].
final class CollectedCrash extends ContCrash {
  /// Map from operation index to the [ContCrash] produced by that operation.
  final Map<int, ContCrash> crashes;

  const CollectedCrash._(this.crashes);

  @override
  String toString() {
    return "CollectedCrash { crashes=$crashes }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! CollectedCrash) {
      return false;
    }

    return crashes == other.crashes;
  }

  @override
  int get hashCode => crashes.hashCode;
}

/// The result of [ContCrash.tryCatch] — either a successfully computed
/// value of type [T] or a [NormalCrash].
///
/// Use [match] to exhaustively handle both cases.
sealed class CrashOr<T> {
  const CrashOr();

  /// Folds this [CrashOr] into a single value of type [R].
  ///
  /// Calls [ifValue] when the computation succeeded, passing the result.
  /// Calls [ifCrash] when the computation threw, passing the [NormalCrash].
  R match<R>(
    R Function(T value) ifValue,
    R Function(NormalCrash crash) ifCrash,
  ) {
    return switch (this) {
      _ValueCrashOr<T>(value: final value) =>
        ifValue(value),
      _CrashCrashOr<T>(crash: final crash) =>
        ifCrash(crash),
    };
  }
}

final class _ValueCrashOr<T> extends CrashOr<T> {
  final T value;

  const _ValueCrashOr(this.value);
}

final class _CrashCrashOr<T> extends CrashOr<T> {
  final NormalCrash crash;

  const _CrashCrashOr(this.crash);
}
