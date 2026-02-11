part of '../../cont.dart';

extension ContAbortExtension<E, A> on Cont<E, A> {
  Cont<E, A> abort(List<ContError> Function(A value) f) {
    return thenDo((a) {
      final errors = f(a);
      return Cont.terminate<E, A>(errors);
    });
  }

  Cont<E, A> abort0(List<ContError> Function() f) {
    return abort((_) {
      return f();
    });
  }

  Cont<E, A> abortWithEnv(
    List<ContError> Function(E env, A value) f,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return abort((a) {
        return f(e, a);
      });
    });
  }

  Cont<E, A> abortWithEnv0(
    List<ContError> Function(E env) f,
  ) {
    return abortWithEnv((e, _) {
      return f(e);
    });
  }

  Cont<E, A> abortWith(List<ContError> errors) {
    errors = errors.toList(); // defensive copy
    return abort0(() {
      return errors;
    });
  }
}
