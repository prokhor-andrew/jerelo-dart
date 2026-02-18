part of '../cont.dart';

final class ContObserver<F, A> {
  final void Function(List<ContError<F>> errors) _onElse;

  final void Function(A value) onThen;

  const ContObserver._(this._onElse, this.onThen);

  void onElse([List<ContError<F>> errors = const []]) {
    _onElse(errors);
  }

  ContObserver<F2, A> copyUpdateOnElse<F2>(
    void Function(List<ContError<F2>> errors) onElse,
  ) {
    return ContObserver._(onElse, onThen);
  }

  ContObserver<F, A2> copyUpdateOnThen<A2>(
    void Function(A2 value) onThen,
  ) {
    return ContObserver._(onElse, onThen);
  }
}
