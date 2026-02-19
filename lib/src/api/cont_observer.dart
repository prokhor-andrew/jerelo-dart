part of '../cont.dart';

final class ContObserver<F, A> {
  final void Function(ContError<F> error) _onElse;

  final void Function(A value) onThen;

  const ContObserver._(this._onElse, this.onThen);

  void onElse(ContError<F> error) {
    _onElse(error);
  }

  ContObserver<F2, A> copyUpdateOnElse<F2>(
    void Function(ContError<F2> error) onElse,
  ) {
    return ContObserver._(onElse, onThen);
  }

  ContObserver<F, A2> copyUpdateOnThen<A2>(
    void Function(A2 value) onThen,
  ) {
    return ContObserver._(onElse, onThen);
  }
}
