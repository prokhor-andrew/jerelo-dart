final class ContObserver<A> {
  final void Function() onNone;
  final void Function(Object error, List<Object> errors) _onFail;
  final void Function(A value) onSome;

  const ContObserver(this.onNone, this._onFail, this.onSome);

  static ContObserver<A> ignore<A>() {
    return ContObserver(() {}, (_, _) {}, (_) {});
  }

  void onFail(Object error, [List<Object> errors = const []]) {
    _onFail(error, errors);
  }

  ContObserver<A> copyUpdateOnNone(void Function() onNone) {
    return ContObserver(onNone, _onFail, onSome);
  }

  ContObserver<A> copyUpdateOnFail(void Function(Object error, List<Object> errors) onFail) {
    return ContObserver(onNone, onFail, onSome);
  }

  ContObserver<A2> copyUpdateOnSome<A2>(void Function(A2 value) onSome) {
    return ContObserver(onNone, _onFail, onSome);
  }
}
