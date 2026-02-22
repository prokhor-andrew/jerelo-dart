sealed class OkPolicy<T> {
  const OkPolicy();

  static OkPolicy<T> sequence<T>() {
    return SequenceOkPolicy();
  }

  static OkPolicy<T> quitFast<T>() {
    return QuitFastOkPolicy();
  }

  static OkPolicy<T> runAll<T>(
    T Function(T t1, T t2) combine, {
    required bool shouldFavorCrash,
  }) {
    return RunAllOkPolicy(
      combine,
      shouldFavorCrash: shouldFavorCrash,
    );
  }
}

final class SequenceOkPolicy<T> extends OkPolicy<T> {
  const SequenceOkPolicy();
}

final class QuitFastOkPolicy<T> extends OkPolicy<T> {
  const QuitFastOkPolicy();
}

final class RunAllOkPolicy<T> extends OkPolicy<T> {
  final T Function(T t1, T t2) combine;
  final bool shouldFavorCrash;
  const RunAllOkPolicy(
    this.combine, {
    required this.shouldFavorCrash,
  });
}
