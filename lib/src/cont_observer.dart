import 'package:jerelo/src/cont_error.dart';
import 'package:jerelo/src/cont_signal.dart';

final class ContObserver<A> {
  // onFatal MUST NOT FAIL EVER.
  final void Function(ContError error, ContSignal signal) onFatal;
  final void Function() onNone;
  final void Function(ContError error, List<ContError> errors) _onFail;
  final void Function(A value) onSome;

  const ContObserver(this.onFatal, this.onNone, this._onFail, this.onSome);

  void onFail(ContError error, [List<ContError> errors = const []]) {
    _onFail(error, errors);
  }
}
