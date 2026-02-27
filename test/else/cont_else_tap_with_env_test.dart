import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTapWithEnv', () {
    test(
        'receives environment and error, promotes on success',
        () {
      String? capturedEnv;
      String? capturedError;
      int? result;

      Cont.error<String, String, int>('oops')
          .elseTapWithEnv((env, error) {
        capturedEnv = env;
        capturedError = error;
        return Cont.of(42);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedError, equals('oops'));
      expect(result, equals(42));
    });

    test('passes through value', () {
      bool called = false;
      int? result;

      Cont.of<String, String, int>(42)
          .elseTapWithEnv((env, error) {
        called = true;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('can be run multiple times', () {
      int tapCount = 0;

      final cont = Cont.error<String, String, int>('oops')
          .elseTapWithEnv((env, _) {
        tapCount++;
        return Cont.of(0);
      });

      cont.run('env');
      cont.run('env');

      expect(tapCount, equals(2));
    });
  });

  group('Cont.elseTapWithEnv0', () {
    test('receives environment only, promotes on success',
        () {
      String? capturedEnv;
      int? result;

      Cont.error<String, String, int>('oops')
          .elseTapWithEnv0((env) {
        capturedEnv = env;
        return Cont.of(99);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(result, equals(99));
    });
  });
}
