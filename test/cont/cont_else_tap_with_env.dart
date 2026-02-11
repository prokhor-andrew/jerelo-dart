import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTapWithEnv', () {
    test('provides env and errors on termination', () {
      String? receivedEnv;
      List<ContError>? receivedErrors;

      Cont.terminate<String, int>([
            ContError.capture('err1'),
          ])
          .elseTapWithEnv((env, errors) {
            receivedEnv = env;
            receivedErrors = errors;
            return Cont.terminate<String, int>([]);
          })
          .run('hello', onTerminate: (_) {});

      expect(receivedEnv, 'hello');
      expect(receivedErrors!.length, 1);
      expect(receivedErrors![0].error, 'err1');
    });

    test('recovers when side effect succeeds', () {
      int? value;

      Cont.terminate<String, int>([
            ContError.capture('err'),
          ])
          .elseTapWithEnv(
            (env, errors) => Cont.of(42),
          )
          .run('hello', onValue: (val) => value = val);

      expect(value, 42);
    });

    test(
      'propagates original errors when side effect fails',
      () {
        List<ContError>? errors;

        Cont.terminate<String, int>([
              ContError.capture('original'),
            ])
            .elseTapWithEnv((env, e) {
              return Cont.terminate<String, int>([
                ContError.capture('side effect'),
              ]);
            })
            .run('hello', onTerminate: (e) => errors = e);

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
            return Cont.terminate<String, int>([]);
          })
          .run('hello', onValue: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('receives defensive copy of errors', () {
      final originalErrors = [
        ContError.capture('err1'),
      ];
      List<ContError>? receivedErrors;

      Cont.terminate<String, int>(originalErrors)
          .elseTapWithEnv((env, errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.terminate<String, int>([]);
          })
          .run('hello', onTerminate: (_) {});

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont =
          Cont.terminate<String, int>().elseTapWithEnv((
            env,
            errors,
          ) {
            callCount++;
            return Cont.terminate<String, int>([]);
          });

      cont.run('hello', onTerminate: (_) {});
      expect(callCount, 1);

      cont.run('world', onTerminate: (_) {});
      expect(callCount, 2);
    });
  });

  group('Cont.elseTapWithEnv0', () {
    test('provides env only', () {
      String? receivedEnv;

      Cont.terminate<String, int>()
          .elseTapWithEnv0((env) {
            receivedEnv = env;
            return Cont.terminate<String, int>([]);
          })
          .run('hello', onTerminate: (_) {});

      expect(receivedEnv, 'hello');
    });

    test(
      'behaves like elseTapWithEnv with ignored errors',
      () {
        var count1 = 0;
        var count2 = 0;

        final cont1 =
            Cont.terminate<String, int>().elseTapWithEnv0(
              (env) {
                count1++;
                return Cont.terminate<String, int>([]);
              },
            );
        final cont2 =
            Cont.terminate<String, int>().elseTapWithEnv(
              (env, _) {
                count2++;
                return Cont.terminate<String, int>([]);
              },
            );

        cont1.run('hello', onTerminate: (_) {});
        cont2.run('hello', onTerminate: (_) {});

        expect(count1, 1);
        expect(count2, 1);
      },
    );
  });
}
