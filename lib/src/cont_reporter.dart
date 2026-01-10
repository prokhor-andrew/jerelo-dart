import 'package:jerelo/src/cont_error.dart';

final class ContReporter {
  final void Function(ContError error) onNone;
  final void Function(ContError error) onFail;
  final void Function(ContError error) onSome;

  const ContReporter({required this.onNone, required this.onFail, required this.onSome});

  static ContReporter ignore() {
    return ContReporter(onNone: (_) {}, onFail: (_) {}, onSome: (_) {});
  }

  ContReporter copyUpdateOnFail(void Function(ContError error) onFail) {
    return ContReporter(onNone: onNone, onFail: onFail, onSome: onSome);
  }

  ContReporter copyUpdateOnNone(void Function(ContError error) onNone) {
    return ContReporter(onNone: onNone, onFail: onFail, onSome: onSome);
  }

  ContReporter copyUpdateOnSome(void Function(ContError error) onSome) {
    return ContReporter(onNone: onNone, onFail: onFail, onSome: onSome);
  }
}
