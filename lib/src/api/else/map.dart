part of '../../cont.dart';

extension ContElseMapExtension<E, A> on Cont<E, A> {
  Cont<E, A> elseMap(
    List<ContError> Function(List<ContError> errors) f,
  ) {
    return elseDo((errors) {
      return Cont.terminate<E, A>(f(errors));
    });
  }

  Cont<E, A> elseMap0(List<ContError> Function() f) {
    return elseMap((_) {
      return f();
    });
  }

  Cont<E, A> elseMapWithEnv(
    List<ContError> Function(E env, List<ContError> errors)
    f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseMap((errors) {
        return f(e, errors);
      });
    });
  }

  Cont<E, A> elseMapWithEnv0(
    List<ContError> Function(E env) f,
  ) {
    return elseMapWithEnv((e, _) {
      return f(e);
    });
  }

  Cont<E, A> elseMapTo(List<ContError> errors) {
    errors = errors.toList(); // defensive copy
    return elseMap0(() {
      return errors;
    });
  }
}
