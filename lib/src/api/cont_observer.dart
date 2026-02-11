part of '../cont.dart';

/// An observer that handles both success and termination cases of a continuation.
///
/// [ContObserver] provides the callback mechanism for receiving results from
/// a [Cont] execution. It encapsulates handlers for both successful values
/// and termination (failure) scenarios.
final class ContObserver<A> {
  final void Function(List<ContError> errors) _onElse;

  /// The callback function invoked when the continuation produces a successful value.
  final void Function(A value) onThen;

  const ContObserver._(this._onElse, this.onThen);

  /// Invokes the termination callback with the provided errors.
  ///
  /// - [errors]: List of errors that caused termination. Defaults to an empty list.
  void onElse([List<ContError> errors = const []]) {
    _onElse(errors);
  }

  /// Creates a new observer with an updated termination handler.
  ///
  /// Returns a copy of this observer with a different termination callback,
  /// while preserving the value callback.
  ///
  /// - [onElse]: The new termination handler to use.
  ContObserver<A> copyUpdateOnElse(
    void Function(List<ContError> errors) onElse,
  ) {
    return ContObserver._(onElse, onThen);
  }

  /// Creates a new observer with an updated value handler and potentially different type.
  ///
  /// Returns a copy of this observer with a different value callback type,
  /// while preserving the termination callback.
  ///
  /// - [onThen]: The new value handler to use.
  ContObserver<A2> copyUpdateOnThen<A2>(
    void Function(A2 value) onThen,
  ) {
    return ContObserver._(onElse, onThen);
  }
}
