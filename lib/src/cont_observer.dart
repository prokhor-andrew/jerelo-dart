part of 'cont.dart';

/// An observer that handles both success and termination cases of a continuation.
///
/// [ContObserver] provides the callback mechanism for receiving results from
/// a [Cont] execution. It encapsulates handlers for both successful values
/// and termination (failure) scenarios.
final class ContObserver<A> {
  final void Function(List<ContError> errors) _onTerminate;

  /// The callback function invoked when the continuation produces a successful value.
  final void Function(A value) onValue;

  /// Creates an observer with termination and value handlers.
  ///
  /// - [_onTerminate]: Handler called when the continuation terminates (fails).
  /// - [onValue]: Handler called when the continuation produces a successful value.
  const ContObserver._(this._onTerminate, this.onValue);

  /// Invokes the termination callback with the provided errors.
  ///
  /// - [errors]: List of errors that caused termination. Defaults to an empty list.
  void onTerminate([List<ContError> errors = const []]) {
    _onTerminate(errors);
  }

  /// Creates a new observer with an updated termination handler.
  ///
  /// Returns a copy of this observer with a different termination callback,
  /// while preserving the value callback.
  ///
  /// - [onTerminate]: The new termination handler to use.
  ContObserver<A> copyUpdateOnTerminate(
    void Function(List<ContError> errors) onTerminate,
  ) {
    return ContObserver._(onTerminate, onValue);
  }

  /// Creates a new observer with an updated value handler and potentially different type.
  ///
  /// Returns a copy of this observer with a different value callback type,
  /// while preserving the termination callback.
  ///
  /// - [onValue]: The new value handler to use.
  ContObserver<A2> copyUpdateOnValue<A2>(
    void Function(A2 value) onValue,
  ) {
    return ContObserver._(onTerminate, onValue);
  }
}
