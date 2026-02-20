part of '../cont.dart';

typedef OnCrash = void Function();

final class ContObserver<F, A> {
  final void Function(NormalCrash crash) _onUnsafePanic;

  final void Function(ContCrash crash) _onCrash;

  final void Function(F error) onElse;

  final void Function(A value) onThen;

  const ContObserver._(
    this._onUnsafePanic,
    this._onCrash,
    this.onElse,
    this.onThen,
  );

  ContObserver<F2, A> copyUpdateOnElse<F2>(
    void Function(F2 error) onElse,
  ) {
    return ContObserver._(
      _onUnsafePanic,
      _onCrash,
      onElse,
      onThen,
    );
  }

  ContObserver<F, A2> copyUpdateOnThen<A2>(
    void Function(A2 value) onThen,
  ) {
    return ContObserver._(
      _onUnsafePanic,
      _onCrash,
      onElse,
      onThen,
    );
  }

  OnCrash? safeRun(void Function() function) {
    try {
      function();

      return null;
    } catch (error, st) {
      return () {
        _onCrash(NormalCrash._(error, st));
      };
    }
  }

  // bool safeMerged(
  //   void Function() left,
  //   void Function() right,
  // ) {
  //   try {
  //     left();
  //     right();
  //   } catch (error, st) {
  //
  //   }
  // }
  //
  // bool safeListed(
  //   List<void Function()> list,
  // ) {
  //   try {} catch (error, st) {}
  // }
}

extension ContObserverAbsurdifyExtension<F, A>
    on ContObserver<F, A> {
  ContObserver<F, A> absurdify() {
    ContObserver<F, A> cont = this;

    if (cont is ContObserver<F, Never>) {
      cont = cont.thenAbsurd<A>();
    }

    if (cont is ContObserver<Never, A>) {
      cont = cont.elseAbsurd<F>();
    }

    return cont;
  }
}

extension ContObserverThenNeverExtension<F>
    on ContObserver<F, Never> {
  ContObserver<F, A> thenAbsurd<A>() {
    return ContObserver._(
      _onUnsafePanic,
      _onCrash,
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
      _onCrash,
      _ignore,
      onThen,
    );
  }
}
