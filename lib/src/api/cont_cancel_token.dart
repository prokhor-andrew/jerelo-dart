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
/// cancelled. A view node (see [_CancelNode._view]) is also cancelled while
/// its predicate returns `true`, but it cannot notify for that predicate: its
/// [onCancel] callbacks are registered on the parent.
final class _CancelNode {
  final _CancelNode? _parent;
  final bool Function()? _predicate;
  final bool _isView;

  bool _isCancelled = false;
  List<_CancelListener>? _listeners;
  void Function()? _unlinkFromParent;

  /// Receives exceptions thrown by [onCancel] callbacks. Set on the root
  /// node by [Cont.run]; child and view nodes use their parent's.
  void Function(NormalCrash crash)? _onPanic;

  _CancelNode._root()
      : _parent = null,
        _predicate = null,
        _isView = false;

  /// A node that is cancelled with its parent, or explicitly via [cancel].
  _CancelNode._child(_CancelNode parent)
      : _parent = parent,
        _predicate = null,
        _isView = false {
    _unlinkFromParent = parent.onCancel(cancel);
  }

  /// A read-only node that reports cancellation when its parent is
  /// cancelled or [predicate] returns `true`.
  _CancelNode._view(
      _CancelNode parent, bool Function() predicate)
      : _parent = parent,
        _predicate = predicate,
        _isView = true;

  bool isCancelled() {
    if (_isCancelled) {
      return true;
    }

    final predicate = _predicate;
    if (predicate != null && predicate()) {
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

    if (_isView) {
      return _parent!.onCancel(callback);
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
