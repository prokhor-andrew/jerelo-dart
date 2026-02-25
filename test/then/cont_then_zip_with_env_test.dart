import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenZipWithEnv', () {
    test('receives environment and value', () {
      String? value;

      Cont.of<String, String, int>(10)
          .thenZipWithEnv(
            (env, a) => Cont.of('$env: $a'),
            (a, b) => '$a -> $b',
          )
          .run('hello', onThen: (val) => value = val);

      expect(value, '10 -> hello: 10');
    });

    test('passes through error', () {
      bool zipCalled = false;
      String? error;

      Cont.error<String, String, int>('err')
          .thenZipWithEnv<int, String>(
        (env, a) {
          zipCalled = true;
          return Cont.of(a * 2);
        },
        (a, b) => '$a + $b',
      ).run('hello', onElse: (e) => error = e);

      expect(zipCalled, false);
      expect(error, 'err');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.of<String, String, int>(5).thenZipWithEnv(
        (env, a) {
          callCount++;
          return Cont.of(a * 2);
        },
        (a, b) => a + b,
      );

      int? value1;
      cont.run('env1', onThen: (val) => value1 = val);
      expect(value1, 15);
      expect(callCount, 1);

      int? value2;
      cont.run('env2', onThen: (val) => value2 = val);
      expect(value2, 15);
      expect(callCount, 2);
    });
  });

  group('Cont.thenZipWithEnv0', () {
    test('receives environment only', () {
      String? value;

      Cont.of<String, String, int>(10)
          .thenZipWithEnv0(
            (env) => Cont.of('$env'),
            (a, b) => '$a -> $b',
          )
          .run('hello', onThen: (val) => value = val);

      expect(value, '10 -> hello');
    });
  });
}
