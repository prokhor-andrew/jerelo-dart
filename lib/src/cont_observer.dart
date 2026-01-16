import 'cont_error.dart';

final class ContObserver<A> {
  final void Function(List<ContError> errors) _onTerminate;
  final void Function(A value) onSome;

  const ContObserver(this._onTerminate, this.onSome);

  static ContObserver<A> ignore<A>() {
    return ContObserver((_) {}, (_) {});
  }

  void onTerminate([List<ContError> errors = const []]) {
    _onTerminate(errors);
  }

  ContObserver<A> copyUpdateOnTerminate(void Function(List<ContError> errors) onTerminate) {
    return ContObserver(onTerminate, onSome);
  }

  ContObserver<A2> copyUpdateOnSome<A2>(void Function(A2 value) onSome) {
    return ContObserver(onTerminate, onSome);
  }
}
