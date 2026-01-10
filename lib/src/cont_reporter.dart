final class ContReporter {
  final void Function(Object error, StackTrace st) onNone;
  final void Function(Object error, StackTrace st) onFail;
  final void Function(Object error, StackTrace st) onSome;

  const ContReporter({
    required this.onNone,
    required this.onFail,
    required this.onSome,
    //
  });

  static ContReporter ignore() {
    return ContReporter(onNone: (_, _) {}, onFail: (_, _) {}, onSome: (_, _) {});
  }

  ContReporter copyUpdateOnNone(void Function(Object error, StackTrace st) onNone) {
    return ContReporter(onNone: onNone, onFail: onFail, onSome: onSome);
  }

  ContReporter copyUpdateOnFail(void Function(Object error, StackTrace st) onFail) {
    return ContReporter(onNone: onNone, onFail: onFail, onSome: onSome);
  }

  ContReporter copyUpdateOnSome(void Function(Object error, StackTrace st) onSome) {
    return ContReporter(onNone: onNone, onFail: onFail, onSome: onSome);
  }
}
