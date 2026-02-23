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

  /// Runs [function] and returns any synchronous exception as a [NormalCrash].
  ///
  /// If [function] completes without throwing, returns `null`.
  /// This helper is used internally to convert raw Dart exceptions into
  /// the [ContCrash] representation.
  static NormalCrash? tryCatch(void Function() function) {
    try {
      function();
      return null;
    } catch (error, st) {
      return NormalCrash._(error, st);
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
/// Produced when two continuations are run (e.g. in [Cont.merge] or
/// [Cont.bracket]) and both crash. Carries the original [left] and [right]
/// crashes so callers can inspect both.
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
/// Produced when [Cont.mergeAll] is run with [RunAllCrashPolicy] and more
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
