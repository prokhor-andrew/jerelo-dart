part of '../cont.dart';

sealed class ContObserver<F, A> {
  final void Function(NormalCrash crash) _onUnsafePanic;

  final void Function(ContCrash crash) onCrash;

  final void Function(F error) onElse;

  final void Function(A value) onThen;

  const ContObserver(
    this._onUnsafePanic,
    this.onCrash,
    this.onElse,
    this.onThen,
  );

  ContObserver<F, A> copyUpdateOnCrash(
    void Function(ContCrash crash) onCrash,
  ) {
    return switch (this) {
      SafeObserver<F, A>(
        isUsed: final isUsed,
        _onUnsafePanic: final _onUnsafePanic,
        onElse: final onElse,
        onThen: final onThen,
      ) =>
        SafeObserver._(
          isUsed,
          _onUnsafePanic,
          onCrash,
          onElse,
          onThen,
        ),
      _UnsafeObserver<F, A>(
        _onUnsafePanic: final _onUnsafePanic,
        onElse: final onElse,
        onThen: final onThen,
      ) =>
        _UnsafeObserver._(
          _onUnsafePanic,
          onCrash,
          onElse,
          onThen,
        ),
    };
  }

  ContObserver<F2, A> copyUpdateOnElse<F2>(
    void Function(F2 error) onElse,
  ) {
    return switch (this) {
      SafeObserver<F, A>(
        isUsed: final isUsed,
        _onUnsafePanic: final _onUnsafePanic,
        onCrash: final onCrash,
        onThen: final onThen,
      ) =>
        SafeObserver._(
          isUsed,
          _onUnsafePanic,
          onCrash,
          onElse,
          onThen,
        ),
      _UnsafeObserver<F, A>(
        _onUnsafePanic: final _onUnsafePanic,
        onCrash: final onCrash,
        onThen: final onThen,
      ) =>
        _UnsafeObserver._(
          _onUnsafePanic,
          onCrash,
          onElse,
          onThen,
        ),
    };
  }

  ContObserver<F, A2> copyUpdateOnThen<A2>(
    void Function(A2 value) onThen,
  ) {
    return switch (this) {
      SafeObserver<F, A>(
        isUsed: final isUsed,
        _onUnsafePanic: final _onUnsafePanic,
        onElse: final onElse,
        onCrash: final onCrash,
      ) =>
        SafeObserver._(
          isUsed,
          _onUnsafePanic,
          onCrash,
          onElse,
          onThen,
        ),
      _UnsafeObserver<F, A>(
        _onUnsafePanic: final _onUnsafePanic,
        onElse: final onElse,
        onCrash: final onCrash,
      ) =>
        _UnsafeObserver._(
          _onUnsafePanic,
          onCrash,
          onElse,
          onThen,
        ),
    };
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
    return switch (this) {
      SafeObserver<F, Never>(
        isUsed: final isUsed,
        _onUnsafePanic: final _onUnsafePanic,
        onElse: final onElse,
        onCrash: final onCrash,
      ) =>
        SafeObserver._(isUsed, _onUnsafePanic, onCrash,
            onElse, _ignore),
      _UnsafeObserver<F, Never>(
        _onUnsafePanic: final _onUnsafePanic,
        onElse: final onElse,
        onCrash: final onCrash,
      ) =>
        _UnsafeObserver._(
            _onUnsafePanic, onCrash, onElse, _ignore),
    };
  }
}

extension ContObserverElseNeverExtension<A>
    on ContObserver<Never, A> {
  ContObserver<F, A> elseAbsurd<F>() {
    return switch (this) {
      SafeObserver<Never, A>(
        isUsed: final isUsed,
        _onUnsafePanic: final _onUnsafePanic,
        onThen: final onThen,
        onCrash: final onCrash,
      ) =>
        SafeObserver._(
          isUsed,
          _onUnsafePanic,
          onCrash,
          _ignore,
          onThen,
        ),
      _UnsafeObserver<Never, A>(
        _onUnsafePanic: final _onUnsafePanic,
        onThen: final onThen,
        onCrash: final onCrash,
      ) =>
        _UnsafeObserver._(
          _onUnsafePanic,
          onCrash,
          _ignore,
          onThen,
        ),
    };
  }
}

final class _UnsafeObserver<F, A>
    extends ContObserver<F, A> {
  const _UnsafeObserver._(
    super._onUnsafePanic,
    super.onCrash,
    super.onElse,
    super.onThen,
  );
}

final class SafeObserver<F, A> extends ContObserver<F, A> {
  final bool Function() isUsed;

  const SafeObserver._(
    this.isUsed,
    super._onUnsafePanic,
    super.onCrash,
    super.onElse,
    super.onThen,
  );
}
