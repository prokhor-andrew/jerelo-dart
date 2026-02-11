import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDoWithEnv', () {
    test('provides both env and value', () {
      String? value;

      Cont.of<String, int>(42)
          .thenDoWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onValue: (val) => value = val);

      expect(value, 'hello: 42');
    });

    test('passes through termination', () {
      List<ContError>? errors;

      Cont.terminate<String, int>([
            ContError.capture('err'),
          ])
          .thenDoWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('terminates when function throws', () {
      final cont = Cont.of<String, int>(42).thenDoWithEnv((
        env,
        a,
      ) {
        throw 'Error';
      });

      ContError? error;
      cont.run(
        'hello',
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Error');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<String, int>(42).thenDoWithEnv((
        env,
        a,
      ) {
        callCount++;
        return Cont.of('$env: $a');
      });

      String? value1;
      cont.run('hello', onValue: (val) => value1 = val);
      expect(value1, 'hello: 42');
      expect(callCount, 1);

      String? value2;
      cont.run('world', onValue: (val) => value2 = val);
      expect(value2, 'world: 42');
      expect(callCount, 2);
    });

    test('never executes on termination', () {
      bool called = false;

      Cont.terminate<String, int>()
          .thenDoWithEnv((env, a) {
            called = true;
            return Cont.of('result');
          })
          .run('hello', onTerminate: (_) {});

      expect(called, false);
    });
  });

  group('Cont.thenDoWithEnv0', () {
    test('provides env only', () {
      String? value;

      Cont.of<String, int>(42)
          .thenDoWithEnv0((env) => Cont.of('env: $env'))
          .run('hello', onValue: (val) => value = val);

      expect(value, 'env: hello');
    });

    test(
      'behaves like thenDoWithEnv with ignored value',
      () {
        String? value1;
        String? value2;

        final cont1 = Cont.of<String, int>(
          42,
        ).thenDoWithEnv0((env) => Cont.of('env: $env'));
        final cont2 = Cont.of<String, int>(
          42,
        ).thenDoWithEnv((env, _) => Cont.of('env: $env'));

        cont1.run('hello', onValue: (val) => value1 = val);
        cont2.run('hello', onValue: (val) => value2 = val);

        expect(value1, value2);
      },
    );
  });
}
