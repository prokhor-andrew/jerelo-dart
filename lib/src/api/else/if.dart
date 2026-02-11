part of '../../cont.dart';

extension ContElseIfExtension<E, A> on Cont<E, A> {
  /// Conditionally recovers from termination when the predicate is satisfied.
  ///
  /// Filters termination based on the predicate. If the predicate returns
  /// `true`, the continuation recovers with the provided value. If the predicate
  /// returns `false`, the continuation continues terminating with the original errors.
  ///
  /// This is the error-channel counterpart to [thenIf]. While [thenIf] filters
  /// values on the success channel, [elseIf] filters errors on the termination
  /// channel and provides conditional recovery.
  ///
  /// This is useful for recovering from specific error conditions while letting
  /// other errors propagate through.
  ///
  /// - [predicate]: Function that tests the error list.
  /// - [value]: The value to recover with when the predicate returns `true`.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.terminate<(), int>([ContError.capture('not found')])
  ///   .elseIf((errors) => errors.first.error == 'not found', 42);
  /// // Recovers with 42
  ///
  /// final cont2 = Cont.terminate<(), int>([ContError.capture('fatal error')])
  ///   .elseIf((errors) => errors.first.error == 'not found', 42);
  /// // Continues terminating with 'fatal error'
  /// ```
  Cont<E, A> elseIf(
    bool Function(List<ContError> errors) predicate,
    A value,
  ) {
    return elseDo((errors) {
      if (predicate(errors)) {
        return Cont.of(value);
      }

      return Cont.terminate<E, A>(errors);
    });
  }

  Cont<E, A> elseIf0(bool Function() predicate, A value) {
    return elseIf((_) {
      return predicate();
    }, value);
  }

  Cont<E, A> elseIfWithEnv(
    bool Function(E env, List<ContError> errors) predicate,
    A value,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseIf((errors) {
        return predicate(e, errors);
      }, value);
    });
  }

  Cont<E, A> elseIfWithEnv0(
    bool Function(E env) predicate,
    A value,
  ) {
    return elseIfWithEnv((e, _) {
      return predicate(e);
    }, value);
  }
}
