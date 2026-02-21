part of '../cont.dart';

final class ContObserver<F, A> {
  final void Function(NormalCrash crash) _onUnsafePanic;

  final void Function(ContCrash crash) onCrash;

  final void Function(F error) onElse;

  final void Function(A value) onThen;

  const ContObserver._(
    this._onUnsafePanic,
    this.onCrash,
    this.onElse,
    this.onThen,
  );

  ContObserver<F, A> copyUpdateOnCrash(
    void Function(ContCrash crash) onCrash,
  ) {
    return ContObserver._(
      _onUnsafePanic,
      onCrash,
      onElse,
      onThen,
    );
  }

  ContObserver<F2, A> copyUpdateOnElse<F2>(
    void Function(F2 error) onElse,
  ) {
    return ContObserver._(
      _onUnsafePanic,
      onCrash,
      onElse,
      onThen,
    );
  }

  ContObserver<F, A2> copyUpdateOnThen<A2>(
    void Function(A2 value) onThen,
  ) {
    return ContObserver._(
      _onUnsafePanic,
      onCrash,
      onElse,
      onThen,
    );
  }
}

extension ContObserverAbsurdifyExtension<F, A>
    on ContObserver<F, A> {
  ContObserver<F, A> thenAbsurdify() {
    ContObserver<F, A> cont = this;

    if (cont is ContObserver<F, Never>) {
      cont = cont.thenAbsurd<A>();
    }
    return cont;
  }

  ContObserver<F, A> elseAbsurdify() {
    ContObserver<F, A> cont = this;

    if (cont is ContObserver<Never, A>) {
      cont = cont.elseAbsurd<F>();
    }

    return cont;
  }

  ContObserver<F, A> absurdify() {
    return thenAbsurdify().elseAbsurdify();
  }
}

extension ContObserverThenNeverExtension<F>
    on ContObserver<F, Never> {
  ContObserver<F, A> thenAbsurd<A>() {
    return ContObserver._(
      _onUnsafePanic,
      onCrash,
      onElse,
      _ignore,
    );
  }
}

extension ContObserverElseNeverExtension<A>
    on ContObserver<Never, A> {
  ContObserver<F, A> elseAbsurd<F>() {
    return ContObserver._(
      _onUnsafePanic,
      onCrash,
      _ignore,
      onThen,
    );
  }
}
