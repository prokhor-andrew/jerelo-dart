import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenZipWithEnv', () {
    test('receives environment and value', () {
      String? capturedEnv;
      int? capturedValue;
      String? result;

      Cont.of<String, Never, int>(10).thenZipWithEnv(
        (env, v) {
          capturedEnv = env;
          capturedValue = v;
          return Cont.of(v * 2);
        },
        (a, b) => '$a+$b',
      ).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedValue, equals(10));
      expect(result, equals('10+20'));
    });

    test('passes through error', () {
      bool called = false;
      String? error;

      Cont.error<String, String, int>('oops')
          .thenZipWithEnv(
        (env, v) {
          called = true;
          return Cont.of(v);
        },
        (a, b) => a + b,
      ).run('myEnv', onElse: (e) => error = e);

      expect(called, isFalse);
      expect(error, equals('oops'));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont =
          Cont.of<int, Never, int>(5).thenZipWithEnv(
        (env, v) => Cont.of(env),
        (a, b) => a + b,
      );

      cont.run(10, onThen: (v) => first = v);
      cont.run(20, onThen: (v) => second = v);

      expect(first, equals(15));
      expect(second, equals(25));
    });
  });

  group('Cont.thenZipWithEnv0', () {
    test('receives environment only', () {
      int? result;

      Cont.of<int, Never, int>(5)
          .thenZipWithEnv0(
            (env) => Cont.of(env * 2),
            (a, b) => a + b,
          )
          .run(10, onThen: (v) => result = v);

      expect(result, equals(25));
    });
  });
}
