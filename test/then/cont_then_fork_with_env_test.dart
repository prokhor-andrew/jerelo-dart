import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenForkWithEnv', () {
    test('receives environment and value', () {
      String? capturedEnv;
      int? capturedValue;
      int? result;

      Cont.of<String, Never, int>(10)
          .thenForkWithEnv((env, v) {
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
          .thenForkWithEnv((env, v) {
        called = true;
        return Cont.of(v);
      }).run('myEnv', onElse: (e) => error = e);

      expect(called, isFalse);
      expect(error, equals('oops'));
    });

    test('can be run multiple times', () {
      int forkCount = 0;

      final cont =
          Cont.of<String, Never, int>(42).thenForkWithEnv(
        (env, v) {
          forkCount++;
          return Cont.of(v);
        },
      );

      cont.run('env');
      cont.run('env');

      expect(forkCount, equals(2));
    });
  });

  group('Cont.thenForkWithEnv0', () {
    test('receives environment only', () {
      String? capturedEnv;
      int? result;

      Cont.of<String, Never, int>(42)
          .thenForkWithEnv0((env) {
        capturedEnv = env;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(result, equals(42));
    });
  });
}
