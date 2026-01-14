final class ContReporter {
  final void Function(Object error, StackTrace st) onTerminate;
  final void Function(Object error, StackTrace st) onSome;

  const ContReporter({
    required this.onTerminate,
    required this.onSome,
    //
  });

  static ContReporter ignore() {
    return ContReporter(onTerminate: (_, _) {}, onSome: (_, _) {});
  }

  ContReporter copyUpdateOnTerminate(void Function(Object error, StackTrace st) onNone) {
    return ContReporter(onTerminate: onTerminate, onSome: onSome);
  }

  ContReporter copyUpdateOnSome(void Function(Object error, StackTrace st) onSome) {
    return ContReporter(onTerminate: onTerminate, onSome: onSome);
  }
}
