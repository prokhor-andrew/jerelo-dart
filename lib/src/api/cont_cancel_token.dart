part of '../cont.dart';

/// Cancels a running continuation.
///
/// Returned by [Cont.run]. Calling [cancel] forwards the cancellation to the
/// parts of the computation that are running, and to the parts that start
/// afterwards. Each part decides what cancelling means and how to report
/// it: a part started with [Cont.fromRun] runs the canceller it returned.
///
/// Calling [cancel] more than once has no additional effect.
final class ContCancelToken {
  final void Function() _cancel;
  bool _isCancelled = false;

  ContCancelToken._(this._cancel);

  /// Returns `true` if [cancel] has been called on this token.
  ///
  /// It does not tell whether the computation has stopped: the computation
  /// reports how it ended through the callbacks passed to [Cont.run].
  bool isCancelled() {
    return _isCancelled;
  }

  /// Cancels the computation.
  ///
  /// Only the first call has an effect.
  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _cancel();
  }
}
