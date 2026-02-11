part of '../../cont.dart';

extension ContElseWhileExtension<E, A> on Cont<E, A> {
  Cont<E, A> elseWhile(
    bool Function(List<ContError> errors) predicate,
  ) {
    return _elseWhile(this, predicate);
  }

  Cont<E, A> elseWhile0(bool Function() predicate) {
    return elseWhile((_) {
      return predicate();
    });
  }

  Cont<E, A> elseWhileWithEnv(
    bool Function(E env, List<ContError> errors) predicate,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseWhile((errors) {
        return predicate(e, errors);
      });
    });
  }

  Cont<E, A> elseWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return elseWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
