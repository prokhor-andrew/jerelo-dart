part of '../../cont.dart';

extension ContElseUntilExtension<E, A> on Cont<E, A> {
  Cont<E, A> elseUntil(
    bool Function(List<ContError> errors) predicate,
  ) {
    return elseWhile((errors) {
      return !predicate(errors);
    });
  }

  Cont<E, A> elseUntil0(bool Function() predicate) {
    return elseUntil((_) {
      return predicate();
    });
  }

  Cont<E, A> elseUntilWithEnv(
    bool Function(E env, List<ContError> errors) predicate,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseUntil((errors) {
        return predicate(e, errors);
      });
    });
  }

  Cont<E, A> elseUntilWithEnv0(
    bool Function(E env) predicate,
  ) {
    return elseUntilWithEnv((e, _) {
      return predicate(e);
    });
  }
}
