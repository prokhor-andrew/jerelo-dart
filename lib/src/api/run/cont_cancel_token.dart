part of '../../cont.dart';

/// A token used to cooperatively cancel a running continuation.
///
/// Returned by [Cont.run], this token provides a way to signal cancellation
/// to a running computation and to query its current cancellation state.
///
/// Cancellation is cooperative: calling [cancel] sets an internal flag that
/// the runtime polls via [isCancelled]. The computation checks this flag
/// at safe points and stops work when it detects cancellation.
///
/// Calling [cancel] multiple times is safe but has no additional effect
/// beyond the first call.
final class ContCancelToken {
  var _isCancelled = false;

  ContCancelToken._();

  /// Returns `true` if [cancel] has been called on this token.
  bool isCancelled() {
    return _isCancelled;
  }

  /// Signals cancellation to the running computation.
  ///
  /// After this call, [isCancelled] will return `true` and the runtime
  /// will detect the cancellation at the next polling point.
  /// Calling this method multiple times is safe but has no additional effect.
  void cancel() {
    _isCancelled = true;
  }
}
