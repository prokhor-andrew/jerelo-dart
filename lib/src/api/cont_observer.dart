part of '../cont.dart';

/// Receives the outcome of a [Cont] computation.
///
/// [ContObserver] is the callback container passed to [Cont.runWith]. It holds
/// three outcome callbacks — [onCrash], [onElse], and [onThen] — exactly one
/// of which will be invoked when the continuation completes.
///
/// Use the `copyUpdate*` family of methods to derive observers with selectively
/// overridden callbacks while preserving the rest of the original observer's state.
sealed class ContObserver<F, A> {
  final void Function(NormalCrash crash) _onUnsafePanic;

  /// Called when the computation terminates on the crash channel.
  ///
  /// Receives the [ContCrash] that describes the unexpected exception.
  final void Function(ContCrash crash) onCrash;

  /// Called when the computation terminates on the else (error) channel.
  ///
  /// Receives the business-logic error value of type [F].
  final void Function(F error) onElse;

  /// Called when the computation succeeds on the then (value) channel.
  ///
  /// Receives the success value of type [A].
  final void Function(A value) onThen;

  const ContObserver(
    this._onUnsafePanic,
    this.onCrash,
    this.onElse,
    this.onThen,
  );

  /// Returns a copy of this observer with a replaced [onCrash] callback.
  ///
  /// All other callbacks are inherited from this observer unchanged.
  ///
  /// - [onCrash]: The new crash callback.
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

  /// Returns a copy of this observer with a replaced [onElse] callback and
  /// a new error type [F2].
  ///
  /// All other callbacks are inherited from this observer unchanged.
  ///
  /// - [onElse]: The new else callback.
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

  /// Returns a copy of this observer with a replaced [onThen] callback and
  /// a new value type [A2].
  ///
  /// All other callbacks are inherited from this observer unchanged.
  ///
  /// - [onThen]: The new then callback.
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

  /// Returns a copy of this observer with all three outcome callbacks replaced.
  ///
  /// The panic handler is inherited from this observer unchanged.
  ///
  /// - [onCrash]: The new crash callback.
  /// - [onElse]: The new else callback.
  /// - [onThen]: The new then callback.
  ContObserver<F2, A2> copyUpdate<F2, A2>({
    required void Function(ContCrash crash) onCrash,
    required void Function(F2 error) onElse,
    required void Function(A2 value) onThen,
  }) {
    return switch (this) {
      SafeObserver<F, A>(
        isUsed: final isUsed,
        _onUnsafePanic: final _onUnsafePanic,
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

/// A [ContObserver] that guards against duplicate callback invocations.
///
/// Provided to the user-supplied run function in [Cont.fromRun]. The [isUsed]
/// predicate returns `true` once any outcome callback has already been called,
/// allowing downstream operators to detect and ignore redundant invocations.
final class SafeObserver<F, A> extends ContObserver<F, A> {
  /// Returns `true` if an outcome callback has already been invoked.
  final bool Function() isUsed;

  const SafeObserver._(
    this.isUsed,
    super._onUnsafePanic,
    super.onCrash,
    super.onElse,
    super.onThen,
  );
}
