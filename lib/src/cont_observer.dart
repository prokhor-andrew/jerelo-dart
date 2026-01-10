import 'package:jerelo/src/cont_error.dart';

final class ContObserver<A> {
  final void Function() onNone;
  final void Function(ContError error, List<ContError> errors) _onFail;
  final void Function(A value) onSome;

  const ContObserver(this.onNone, this._onFail, this.onSome);

  static ContObserver<A> ignore<A>() {
    return ContObserver(() {}, (_, _) {}, (_) {});
  }

  void onFail(ContError error, [List<ContError> errors = const []]) {
    _onFail(error, errors);
  }

  ContObserver<A> copyUpdateOnNone(void Function() onNone) {
    return ContObserver(onNone, _onFail, onSome);
  }

  ContObserver<A> copyUpdateOnFail(void Function(ContError error, List<ContError> errors) onFail) {
    return ContObserver(onNone, onFail, onSome);
  }

  ContObserver<A2> copyUpdateOnSome<A2>(void Function(A2 value) onSome) {
    return ContObserver(onNone, _onFail, onSome);
  }
}
