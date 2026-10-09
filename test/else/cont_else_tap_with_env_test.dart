import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTapWithEnv', () {
    test('provides env and errors on termination', () {
      String? receivedEnv;
      List<ContError>? receivedErrors;

      Cont.stop<String, int>([ContError.capture('err1')])
          .elseTapWithEnv((env, errors) {
            receivedEnv = env;
            receivedErrors = errors;
            return Cont.stop<String, int>([]);
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
      expect(receivedErrors!.length, 1);
      expect(receivedErrors![0].error, 'err1');
    });

    test('recovers when side effect succeeds', () {
      int? value;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseTapWithEnv((env, errors) => Cont.of(42))
          .run('hello', onThen: (val) => value = val);

      expect(value, 42);
    });

    test(
      'propagates original errors when side effect fails',
      () {
        List<ContError>? errors;

        Cont.stop<String, int>([
              ContError.capture('original'),
            ])
            .elseTapWithEnv((env, e) {
              return Cont.stop<String, int>([
                ContError.capture('side effect'),
              ]);
            })
            .run('hello', onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'original');
      },
    );

    test('never executes on value path', () {
      bool called = false;
      int? value;

      Cont.of<String, int>(42)
          .elseTapWithEnv((env, errors) {
            called = true;
            return Cont.stop<String, int>([]);
          })
          .run('hello', onThen: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('receives defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<String, int>(originalErrors)
          .elseTapWithEnv((env, errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.stop<String, int>([]);
          })
          .run('hello', onElse: (_) {});

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.stop<String, int>().elseTapWithEnv((
        env,
        errors,
      ) {
        callCount++;
        return Cont.stop<String, int>([]);
      });

      cont.run('hello', onElse: (_) {});
      expect(callCount, 1);

      cont.run('world', onElse: (_) {});
      expect(callCount, 2);
    });
  });

  group('Cont.elseTapWithEnv0', () {
    test('provides env only', () {
      String? receivedEnv;

      Cont.stop<String, int>()
          .elseTapWithEnv0((env) {
            receivedEnv = env;
            return Cont.stop<String, int>([]);
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
    });

    test(
      'behaves like elseTapWithEnv with ignored errors',
      () {
        var count1 = 0;
        var count2 = 0;

        final cont1 = Cont.stop<String, int>()
            .elseTapWithEnv0((env) {
              count1++;
              return Cont.stop<String, int>([]);
            });
        final cont2 = Cont.stop<String, int>()
            .elseTapWithEnv((env, _) {
              count2++;
              return Cont.stop<String, int>([]);
            });

        cont1.run('hello', onElse: (_) {});
        cont2.run('hello', onElse: (_) {});

        expect(count1, 1);
        expect(count2, 1);
      },
    );
  });
}
