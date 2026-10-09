part of '../cont.dart';

/// A token used to cooperatively cancel a running continuation.
///
/// Returned by [Cont.run], this token provides a way to signal cancellation
/// to a running computation and to query its current cancellation state.
///
/// Cancellation is cooperative: calling [cancel] sets an internal flag that
/// the runtime polls via [ContRuntime.isCancelled]. The computation checks
/// this flag at safe points and stops work when it detects cancellation.
/// Calling [cancel] also runs the callbacks registered with
/// [ContRuntime.onCancel], so that work which is waiting (for example a
/// [Cont.bracket] holding a resource) can react immediately.
///
/// Calling [cancel] multiple times is safe but has no additional effect
/// beyond the first call.
final class ContCancelToken {
  final _CancelNode _node = _CancelNode._root();

  ContCancelToken._();

  /// Returns `true` if [cancel] has been called on this token.
  bool isCancelled() {
    return _node.isCancelled();
  }

  /// Signals cancellation to the running computation.
  ///
  /// After this call, [isCancelled] will return `true` and the runtime
  /// will detect the cancellation at the next polling point. Callbacks
  /// registered with [ContRuntime.onCancel] run immediately, in reverse
  /// order of registration.
  /// Calling this method multiple times is safe but has no additional effect.
  void cancel() {
    _node.cancel();
  }
}

/// The cancellation state behind a [ContCancelToken] and the runtimes
/// derived from it.
///
/// A node is cancelled when [cancel] is called on it, or when its parent is
/// cancelled.
final class _CancelNode {
  final _CancelNode? _parent;

  bool _isCancelled = false;
  List<_CancelListener>? _listeners;
  void Function()? _unlinkFromParent;

  /// Receives exceptions thrown by [onCancel] callbacks. Set on the root
  /// node by [Cont.run]; child nodes use their parent's.
  void Function(NormalCrash crash)? _onPanic;

  _CancelNode._root() : _parent = null;

  /// A node that is cancelled with its parent, or explicitly via [cancel].
  _CancelNode._child(_CancelNode parent)
      : _parent = parent {
    _unlinkFromParent = parent.onCancel(cancel);
  }

  bool isCancelled() {
    if (_isCancelled) {
      return true;
    }

    final parent = _parent;
    return parent != null && parent.isCancelled();
  }

  void Function() onCancel(void Function() callback) {
    if (isCancelled()) {
      _runCallback(callback);
      return _voidIgnore;
    }

    final listener = _CancelListener(callback);
    (_listeners ??= []).add(listener);
    return () {
      _listeners?.remove(listener);
    };
  }

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;

    _unlinkFromParent?.call();
    _unlinkFromParent = null;

    final listeners = _listeners;
    _listeners = null;
    if (listeners == null) {
      return;
    }

    // reverse order, so that nested resources are released inner first
    for (final listener in listeners.reversed) {
      _runCallback(listener.callback);
    }
  }

  void Function(NormalCrash crash) _panicHandler() {
    return _onPanic ?? _parent?._panicHandler() ?? _panic;
  }

  void _runCallback(void Function() callback) {
    ContCrash.tryCatch(callback).match((_) {}, (crash) {
      ContCrash.tryCatch(() {
        _panicHandler()(crash);
      }).match((_) {}, (panic) {
        // if onPanic itself crashes, report that crash
        _panic(panic);
      });
    });
  }
}

final class _CancelListener {
  final void Function() callback;

  _CancelListener(this.callback);
}
