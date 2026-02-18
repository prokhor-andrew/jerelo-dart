sealed class ContError<F> {
  const ContError();
}

final class ManualError<F> extends ContError<F> {
  final F error;

  const ManualError(this.error);

  @override
  String toString() {
    return "ManualError { error=$error }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! ManualError<F>) {
      return false;
    }

    return error == other.error;
  }

  @override
  int get hashCode => error.hashCode;
}

final class ThrownError<F> extends ContError<F> {
  final Object error;

  final StackTrace stackTrace;

  const ThrownError(this.error, this.stackTrace);

  static ThrownError<F> withNoStackTrace<F>(Object error) {
    return ThrownError(error, StackTrace.empty);
  }

  static ThrownError<F> withCurrentStackTrace<F>(
      Object error) {
    return ThrownError(error, StackTrace.current);
  }

  @override
  String toString() {
    return "ThrownError { error=$error, stackTrace=$stackTrace }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! ThrownError<F>) {
      return false;
    }

    return error == other.error;
  }

  @override
  int get hashCode => error.hashCode;
}
