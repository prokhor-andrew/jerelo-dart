part of '../cont.dart';

/// How a continuation ended: with a value, an error or a crash.
///
/// Read it with `switch` on its cases, [ThenBracketOutcome], [ElseBracketOutcome] and
/// [CrashBracketOutcome]. [Cont.bracket] passes it to `release`, so `release`
/// knows what ended `use`.
sealed class BracketOutcome<F, A> {
  const BracketOutcome();
}

/// An [BracketOutcome] for a continuation that succeeded with [value].
final class ThenBracketOutcome<F, A>
    extends BracketOutcome<F, A> {
  /// The value the continuation succeeded with.
  final A value;

  const ThenBracketOutcome._(this.value);

  @override
  String toString() => 'ThenBracketOutcome($value)';

  @override
  bool operator ==(Object other) {
    return other is ThenBracketOutcome &&
        value == other.value;
  }

  @override
  int get hashCode =>
      Object.hash(ThenBracketOutcome, value);
}

/// An [BracketOutcome] for a continuation that failed with [error].
final class ElseBracketOutcome<F, A>
    extends BracketOutcome<F, A> {
  /// The business-logic error the continuation failed with.
  final F error;

  const ElseBracketOutcome._(this.error);

  @override
  String toString() => 'ElseBracketOutcome($error)';

  @override
  bool operator ==(Object other) {
    return other is ElseBracketOutcome &&
        error == other.error;
  }

  @override
  int get hashCode =>
      Object.hash(ElseBracketOutcome, error);
}

/// An [BracketOutcome] for a continuation that crashed with [crash].
final class CrashBracketOutcome<F, A>
    extends BracketOutcome<F, A> {
  /// The crash the continuation ended with.
  final ContCrash crash;

  const CrashBracketOutcome._(this.crash);

  @override
  String toString() => 'CrashBracketOutcome($crash)';

  @override
  bool operator ==(Object other) {
    return other is CrashBracketOutcome &&
        crash == other.crash;
  }

  @override
  int get hashCode =>
      Object.hash(CrashBracketOutcome, crash);
}
