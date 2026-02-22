sealed class CrashPolicy<E, A> {
  const CrashPolicy();

  static CrashPolicy<E, A> sequence<E, A>() {
    return SequenceCrashPolicy();
  }

  static CrashPolicy<E, A> quitFast<E, A>() {
    return QuitFastCrashPolicy();
  }

  static CrashPolicy<E, A> runAll<E, A>({
    required bool shouldFavorElse,
    required E Function(E e1, E e2) combineElseVals,
    required A Function(A a1, A a2) combineThenVals,
  }) {
    return RunAllCrashPolicy(
      shouldFavorElse: shouldFavorElse,
      combineElseVals: combineElseVals,
      combineThenVals: combineThenVals,
    );
  }
}

final class SequenceCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  const SequenceCrashPolicy();
}

final class QuitFastCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  const QuitFastCrashPolicy();
}

final class RunAllCrashPolicy<E, A>
    extends CrashPolicy<E, A> {
  final bool shouldFavorElse;
  final E Function(E e1, E e2) combineElseVals;
  final A Function(A a1, A a2) combineThenVals;

  const RunAllCrashPolicy({
    required this.shouldFavorElse,
    required this.combineElseVals,
    required this.combineThenVals,
  });
}
