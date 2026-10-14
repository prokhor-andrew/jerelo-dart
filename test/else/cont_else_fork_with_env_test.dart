import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseForkWithEnv', () {
    test('receives environment and error', () {
      String? capturedEnv;
      String? capturedError;
      String? error;

      Cont.error<String, String, int>('oops')
          .elseForkWithEnv((env, e) {
        capturedEnv = env;
        capturedError = e;
        return Cont.of(0);
      }).run('myEnv', onElse: (e) => error = e);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedError, equals('oops'));
      expect(error, equals('oops'));
    });

    test('passes through value', () {
      bool called = false;
      int? result;

      Cont.of<String, String, int>(42)
          .elseForkWithEnv((env, e) {
        called = true;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('can be run multiple times', () {
      int forkCount = 0;

      final cont = Cont.error<String, String, int>('err')
          .elseForkWithEnv((env, _) {
        forkCount++;
        return Cont.of(0);
      });

      cont.run('env');
      cont.run('env');

      expect(forkCount, equals(2));
    });
  });

  group('Cont.elseForkWithEnv0', () {
    test('receives environment only', () {
      String? capturedEnv;
      String? error;

      Cont.error<String, String, int>('oops')
          .elseForkWithEnv0((env) {
        capturedEnv = env;
        return Cont.of(0);
      }).run('myEnv', onElse: (e) => error = e);

      expect(capturedEnv, equals('myEnv'));
      expect(error, equals('oops'));
    });
  });
}
