import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

NormalCrash crashOf(Object error) {
  return switch (ContCrash.tryCatch<void>(() {
    throw error;
  })) {
    CrashCrashOr(crash: final crash) => crash,
    ValueCrashOr() => throw StateError('expected a crash'),
  };
}

void main() {
  group('Cont.crash', () {
    test('terminates on the crash channel', () {
      final crash = crashOf('boom');
      ContCrash? received;

      Cont.crash<(), String, int>(crash)
          .run((), onCrash: (c) => received = c);

      expect(received, same(crash));
    });
  });

  group('Cont.crashDo', () {
    test('recovers from a crash with a value', () {
      int? result;

      Cont.crash<(), String, int>(crashOf('boom'))
          .crashDo((_) => Cont.of(1))
          .run((), onThen: (v) => result = v);

      expect(result, equals(1));
    });

    test('can turn a crash into an error', () {
      String? error;

      Cont.crash<(), String, int>(crashOf('boom'))
          .crashDo((c) =>
              Cont.error('was ${(c as NormalCrash).error}'))
          .run((), onElse: (e) => error = e);

      expect(error, equals('was boom'));
    });

    test('passes values and errors through', () {
      int? result;
      String? error;
      var called = false;

      Cont.of<(), String, int>(1).crashDo((_) {
        called = true;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);
      Cont.error<(), String, int>('e').crashDo((_) {
        called = true;
        return Cont.of(0);
      }).run((), onElse: (e) => error = e);

      expect(result, equals(1));
      expect(error, equals('e'));
      expect(called, isFalse);
    });

    test('a throw from f becomes a crash', () {
      ContCrash? crash;

      Cont.crash<(), String, int>(crashOf('first'))
          .crashDo((_) => throw 'second')
          .run((), onCrash: (c) => crash = c);

      expect(
          (crash! as NormalCrash).error, equals('second'));
    });
  });

  group('Cont.runWith', () {
    test('runs with an observer derived from a parent', () {
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        Cont.of<(), String, int>(5)
            .runWith(runtime, observer);
      }).run((), onThen: (v) => result = v);

      expect(result, equals(5));
    });
  });

  group('Error-channel composition', () {
    test('elseInject passes the error as the environment',
        () {
      String? result;

      Cont.error<(), int, String>(7)
          .elseInject(
        Cont.askThen<int, String>()
            .thenMap((e) => 'env $e'),
      )
          .run((), onThen: (v) => result = v);

      expect(result, equals('env 7'));
    });

    test('elseInject passes values through', () {
      String? result;

      Cont.of<(), int, String>('ok')
          .elseInject(
              Cont.of<int, String, String>('unused'))
          .run((), onThen: (v) => result = v);

      expect(result, equals('ok'));
    });

    test(
        'injectedByThen is thenInject with the receiver reversed',
        () {
      int? result;

      Cont.askThen<int, String>()
          .thenMap((env) => env * 2)
          .injectedByThen(Cont.of<(), String, int>(21))
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test(
        'injectedByElse is elseInject with the receiver reversed',
        () {
      String? result;

      Cont.askThen<int, String>()
          .thenMap((env) => 'env $env')
          .injectedByElse(Cont.error<(), int, String>(3))
          .run((), onThen: (v) => result = v);

      expect(result, equals('env 3'));
    });
  });
}
