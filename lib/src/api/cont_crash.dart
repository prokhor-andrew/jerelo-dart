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

  /// Creates a [MergedCrash] combining [left] and [right].
  static ContCrash merge(ContCrash left, ContCrash right) {
    return MergedCrash._(left, right);
  }

  /// Creates a [CollectedCrash] from a map of [crashes].
  static ContCrash collect(Map<int, ContCrash> crashes) {
    return CollectedCrash._(crashes);
  }

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
      return ValueCrashOr._(value);
    } catch (error, st) {
      return CrashCrashOr._(NormalCrash._(error, st));
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
/// Produced when two continuations are run (e.g. in [Cont.coalesce],
/// `crashZip` from jerelo_ext, or [Cont.both]/[Cont.either] with
/// [RunAllOkPolicy]) and both crash. Carries the original [left] and
/// [right] crashes so callers can inspect both.
/// Can also be created directly or with [ContCrash.merge].
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
  int get hashCode => Object.hash(left, right);
}

/// A crash that collects multiple crashes from a list of operations.
///
/// Produced by:
/// - [Cont.converge] with any policy when every continuation crashes, and
///   by an empty [Cont.converge] (with an empty map);
/// - [Cont.all] and [Cont.any] with [RunAllOkPolicy] whenever they report a
///   crash, even if only one continuation crashed.
///
/// The [crashes] map associates each continuation's index with its
/// [ContCrash]. Can also be created directly or with [ContCrash.collect].
final class CollectedCrash extends ContCrash {
  /// Map from operation index to the [ContCrash] produced by that operation.
  final Map<int, ContCrash> crashes;

  const CollectedCrash._(this.crashes);

  @override
  String toString() {
    return "CollectedCrash { $crashes }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! CollectedCrash) {
      return false;
    }

    if (crashes.length != other.crashes.length) {
      return false;
    }

    for (final MapEntry(:key, :value) in crashes.entries) {
      if (!other.crashes.containsKey(key) ||
          other.crashes[key] != value) {
        return false;
      }
    }

    return true;
  }

  @override
  int get hashCode {
    return Object.hashAllUnordered(
      crashes.entries.map((entry) {
        return Object.hash(entry.key, entry.value);
      }),
    );
  }
}

/// The result of [ContCrash.tryCatch] — either a successfully computed
/// value of type [T] or a [NormalCrash].
///
/// Read it with `switch` on its cases, [ValueCrashOr] and [CrashCrashOr].
sealed class CrashOr<T> {
  const CrashOr();
}

/// Internal helper: runs [onCrash] when the computation threw.
extension _CrashOrIfCrash<T> on CrashOr<T> {
  void _ifCrash(void Function(NormalCrash crash) onCrash) {
    switch (this) {
      case CrashCrashOr<T>(crash: final crash):
        onCrash(crash);
      case ValueCrashOr<T>():
        break;
    }
  }
}

/// A [CrashOr] for a computation that returned [value].
final class ValueCrashOr<T> extends CrashOr<T> {
  /// The value the computation returned.
  final T value;

  const ValueCrashOr._(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! ValueCrashOr) {
      return false;
    }

    return other.value == value;
  }

  @override
  int get hashCode => Object.hash(ValueCrashOr, value);

  @override
  String toString() {
    return 'ValueCrashOr($value)';
  }
}

/// A [CrashOr] for a computation that threw, captured as [crash].
final class CrashCrashOr<T> extends CrashOr<T> {
  /// The crash the computation threw.
  final NormalCrash crash;

  const CrashCrashOr._(this.crash);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! CrashCrashOr) {
      return false;
    }

    return other.crash == crash;
  }

  @override
  int get hashCode => Object.hash(CrashCrashOr, crash);

  @override
  String toString() {
    return 'CrashCrashOr($crash)';
  }
}
