import 'cont_error.dart';

final class ContObserver<A> {
  final void Function(List<ContError> errors) _onTerminate;
  final void Function(A value) onValue;

  const ContObserver(this._onTerminate, this.onValue);

  static ContObserver<A> ignore<A>() {
    return ContObserver((_) {}, (_) {});
  }

  void onTerminate([List<ContError> errors = const []]) {
    _onTerminate(errors);
  }

  ContObserver<A> copyUpdateOnTerminate(void Function(List<ContError> errors) onTerminate) {
    return ContObserver(onTerminate, onValue);
  }

  ContObserver<A2> copyUpdateOnValue<A2>(void Function(A2 value) onValue) {
    return ContObserver(onTerminate, onValue);
  }
}
