import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenTapWithEnv', () {
    test('preserves original value', () {
      int? value;

      Cont.of<String, int>(42)
          .thenTapWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onThen: (val) => value = val);

      expect(value, 42);
    });

    test('provides both env and value to side effect', () {
      String? receivedEnv;
      int? receivedValue;

      Cont.of<String, int>(42)
          .thenTapWithEnv((env, a) {
            receivedEnv = env;
            receivedValue = a;
            return Cont.of(());
          })
          .run('hello');

      expect(receivedEnv, 'hello');
      expect(receivedValue, 42);
    });

    test('passes through termination', () {
      List<ContError>? errors;

      Cont.stop<String, int>([
            ContError.capture('err'),
          ])
          .thenTapWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('terminates when side effect terminates', () {
      List<ContError>? errors;

      Cont.of<String, int>(42)
          .thenTapWithEnv((env, a) {
            return Cont.stop<String, ()>([
              ContError.capture('side effect error'),
            ]);
          })
          .run('hello', onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'side effect error');
    });

    test('never executes on termination', () {
      bool called = false;

      Cont.stop<String, int>()
          .thenTapWithEnv((env, a) {
            called = true;
            return Cont.of(());
          })
          .run('hello', onElse: (_) {});

      expect(called, false);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<String, int>(42).thenTapWithEnv((
        env,
        a,
      ) {
        callCount++;
        return Cont.of(());
      });

      int? value1;
      cont.run('hello', onThen: (val) => value1 = val);
      expect(value1, 42);
      expect(callCount, 1);

      int? value2;
      cont.run('world', onThen: (val) => value2 = val);
      expect(value2, 42);
      expect(callCount, 2);
    });
  });

  group('Cont.thenTapWithEnv0', () {
    test('provides env only', () {
      String? receivedEnv;

      Cont.of<String, int>(42)
          .thenTapWithEnv0((env) {
            receivedEnv = env;
            return Cont.of(());
          })
          .run('hello');

      expect(receivedEnv, 'hello');
    });

    test('preserves original value', () {
      int? value;

      Cont.of<String, int>(42)
          .thenTapWithEnv0((env) => Cont.of('side: $env'))
          .run('hello', onThen: (val) => value = val);

      expect(value, 42);
    });

    test(
      'behaves like thenTapWithEnv with ignored value',
      () {
        int? value1;
        int? value2;
        var count1 = 0;
        var count2 = 0;

        final cont1 = Cont.of<String, int>(42)
            .thenTapWithEnv0((env) {
              count1++;
              return Cont.of(());
            });
        final cont2 = Cont.of<String, int>(42)
            .thenTapWithEnv((env, _) {
              count2++;
              return Cont.of(());
            });

        cont1.run('hello', onThen: (val) => value1 = val);
        cont2.run('hello', onThen: (val) => value2 = val);

        expect(value1, value2);
        expect(count1, 1);
        expect(count2, 1);
      },
    );
  });
}
