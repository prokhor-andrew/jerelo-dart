import 'cont_error.dart';

final class ContReporter {
  final void Function(ContError error) onTerminate;
  final void Function(ContError error) onSome;

  const ContReporter({
    required this.onTerminate,
    required this.onSome,
    //
  });

  static ContReporter ignore() {
    return ContReporter(onTerminate: (_) {}, onSome: (_) {});
  }

  ContReporter copyUpdateOnTerminate(void Function(ContError error) onNone) {
    return ContReporter(onTerminate: onTerminate, onSome: onSome);
  }

  ContReporter copyUpdateOnSome(void Function(ContError error) onSome) {
    return ContReporter(onTerminate: onTerminate, onSome: onSome);
  }
}
