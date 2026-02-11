import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenZipWithEnv', () {
    test('combines values with env access', () {
      String? value;

      Cont.of<String, int>(10)
          .thenZipWithEnv(
            (env, a) => Cont.of('$env-$a'),
            (a, b) => '$b=$a',
          )
          .run('cfg', onValue: (val) => value = val);

      expect(value, 'cfg-10=10');
    });

    test('provides env and first value', () {
      String? receivedEnv;
      int? receivedValue;

      Cont.of<String, int>(42)
          .thenZipWithEnv((env, a) {
            receivedEnv = env;
            receivedValue = a;
            return Cont.of(0);
          }, (a, b) => a + b)
          .run('hello');

      expect(receivedEnv, 'hello');
      expect(receivedValue, 42);
    });

    test('passes through termination', () {
      List<ContError>? errors;

      Cont.terminate<String, int>([
            ContError.capture('err'),
          ])
          .thenZipWithEnv(
            (env, a) => Cont.of(0),
            (a, b) => a + b,
          )
          .run('hello', onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test(
      'terminates when second continuation terminates',
      () {
        List<ContError>? errors;

        Cont.of<String, int>(42)
            .thenZipWithEnv(
              (env, a) => Cont.terminate<String, int>([
                ContError.capture('second err'),
              ]),
              (a, b) => a + b,
            )
            .run('hello', onTerminate: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'second err');
      },
    );

    test('terminates when combine throws', () {
      final cont =
          Cont.of<String, int>(5).thenZipWithEnv(
        (env, a) => Cont.of(10),
        (a, b) {
          throw 'Combine Error';
        },
      );

      ContError? error;
      cont.run(
        'hello',
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Combine Error');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<String, int>(
        5,
      ).thenZipWithEnv((env, a) {
        callCount++;
        return Cont.of(env.length);
      }, (a, b) => a + b);

      int? value1;
      cont.run('hi', onValue: (val) => value1 = val);
      expect(value1, 7); // 5 + 2
      expect(callCount, 1);

      int? value2;
      cont.run('hello', onValue: (val) => value2 = val);
      expect(value2, 10); // 5 + 5
      expect(callCount, 2);
    });
  });

  group('Cont.thenZipWithEnv0', () {
    test('provides env only', () {
      String? value;

      Cont.of<String, int>(10)
          .thenZipWithEnv0(
            (env) => Cont.of(env.length),
            (a, b) => '$a+$b',
          )
          .run('hello', onValue: (val) => value = val);

      expect(value, '10+5');
    });

    test(
      'behaves like thenZipWithEnv with ignored value',
      () {
        String? value1;
        String? value2;

        final cont1 = Cont.of<String, int>(
          10,
        ).thenZipWithEnv0(
          (env) => Cont.of(env.length),
          (a, b) => '$a+$b',
        );
        final cont2 = Cont.of<String, int>(
          10,
        ).thenZipWithEnv(
          (env, _) => Cont.of(env.length),
          (a, b) => '$a+$b',
        );

        cont1.run('hello', onValue: (val) => value1 = val);
        cont2.run('hello', onValue: (val) => value2 = val);

        expect(value1, value2);
      },
    );
  });
}
