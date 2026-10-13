import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDoWithEnv', () {
    test('receives environment and error', () {
      String? capturedEnv;
      String? capturedError;
      int? result;

      Cont.error<String, String, int>('oops')
          .elseDoWithEnv((env, error) {
        capturedEnv = env;
        capturedError = error;
        return Cont.of(42);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedError, equals('oops'));
      expect(result, equals(42));
    });

    test('passes through value path', () {
      bool called = false;
      int? result;

      Cont.of<String, String, int>(42)
          .elseDoWithEnv((env, error) {
        called = true;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont = Cont.error<int, String, int>('err')
          .elseDoWithEnv((env, _) => Cont.of(env));

      cont.run(10, onThen: (v) => first = v);
      cont.run(20, onThen: (v) => second = v);

      expect(first, equals(10));
      expect(second, equals(20));
    });
  });

  group('Cont.elseDoWithEnv0', () {
    test('receives environment only', () {
      String? capturedEnv;
      int? result;

      Cont.error<String, String, int>('oops')
          .elseDoWithEnv0((env) {
        capturedEnv = env;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(result, equals(0));
    });
  });
}
