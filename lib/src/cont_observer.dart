final class ContObserver<A> {
  final void Function(List<Object> errors) _onTerminate;
  final void Function(A value) onSome;

  const ContObserver(this._onTerminate, this.onSome);

  static ContObserver<A> ignore<A>() {
    return ContObserver((_) {}, (_) {});
  }

  void onTerminate([List<Object> errors = const []]) {
    _onTerminate(errors);
  }

  ContObserver<A> copyUpdateOnTerminate(void Function(List<Object> errors) onTerminate) {
    return ContObserver(onTerminate, onSome);
  }

  ContObserver<A2> copyUpdateOnSome<A2>(void Function(A2 value) onSome) {
    return ContObserver(onTerminate, onSome);
  }
}
