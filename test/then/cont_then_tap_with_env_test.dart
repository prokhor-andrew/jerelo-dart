import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenTapWithEnv', () {
    test('receives environment and value', () {
      String? capturedEnv;
      int? capturedValue;
      int? result;

      Cont.of<String, Never, int>(10)
          .thenTapWithEnv((env, v) {
        capturedEnv = env;
        capturedValue = v;
        return Cont.of(v * 2);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedValue, equals(10));
      expect(result, equals(10));
    });

    test('passes through error', () {
      bool called = false;
      String? error;

      Cont.error<String, String, int>('oops')
          .thenTapWithEnv((env, v) {
        called = true;
        return Cont.of(v);
      }).run('myEnv', onElse: (e) => error = e);

      expect(called, isFalse);
      expect(error, equals('oops'));
    });

    test('can be run multiple times', () {
      int tapCount = 0;
      int? result;

      final cont =
          Cont.of<String, Never, int>(42).thenTapWithEnv(
        (env, v) {
          tapCount++;
          return Cont.of(v);
        },
      );

      cont.run('env', onThen: (v) => result = v);
      cont.run('env', onThen: (v) => result = v);

      expect(tapCount, equals(2));
      expect(result, equals(42));
    });
  });

  group('Cont.thenTapWithEnv0', () {
    test('receives environment only', () {
      String? capturedEnv;
      int? result;

      Cont.of<String, Never, int>(42)
          .thenTapWithEnv0((env) {
        capturedEnv = env;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(result, equals(42));
    });
  });
}
