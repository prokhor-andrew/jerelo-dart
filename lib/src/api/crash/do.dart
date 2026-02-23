import 'package:jerelo/jerelo.dart';

extension ContCrashDoExtension<E, F, A> on Cont<E, F, A> {
  Cont<E, F, A> crashDo(
    Cont<E, F, A> Function(ContCrash crash) f,
  ) {
    return Cont.fromRun((runtime, observer) {
      runWith(
        runtime,
        observer.copyUpdateOnCrash((initialCrash) {
          if (runtime.isCancelled()) {
            return;
          }

          final resultCrash = ContCrash.tryCatch(() {
            final cont = f(initialCrash).absurdify();
            cont.runWith(runtime, observer);
          });

          if (resultCrash != null) {
            observer.onCrash(resultCrash);
          }
        }),
      );
    });
  }

  Cont<E, F, A> crashDo0(Cont<E, F, A> Function() f) {
    return crashDo((_) {
      return f();
    });
  }

  Cont<E, F, A> crashDoWithEnv(
    Cont<E, F, A> Function(E env, ContCrash crash) f,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashDo((crash) {
        return f(e, crash);
      });
    });
  }

  Cont<E, F, A> crashDoWithEnv0(
    Cont<E, F, A> Function(E env) f,
  ) {
    return crashDoWithEnv((e, _) {
      return f(e);
    });
  }
}
