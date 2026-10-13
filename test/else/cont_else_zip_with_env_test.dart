import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseZipWithEnv', () {
    test('receives environment and error', () {
      String? capturedEnv;
      String? capturedError;
      String? result;

      Cont.error<String, String, int>('oops')
          .elseZipWithEnv(
        (env, error) {
          capturedEnv = env;
          capturedError = error;
          return Cont.error<String, String, int>('second');
        },
        (a, b) => '$a+$b',
      ).run('myEnv', onElse: (e) => result = e);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedError, equals('oops'));
      expect(result, equals('oops+second'));
    });

    test('passes through value', () {
      bool called = false;
      int? result;

      Cont.of<String, String, int>(42).elseZipWithEnv(
        (env, error) {
          called = true;
          return Cont.error<String, String, int>('oops');
        },
        (a, b) => '$a+$b',
      ).run('myEnv', onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('can be run multiple times', () {
      String? first;
      String? second;

      final cont = Cont.error<String, String, int>('err')
          .elseZipWithEnv(
        (env, _) => Cont.error<String, String, int>(env),
        (a, b) => '$a+$b',
      );

      cont.run('envA', onElse: (e) => first = e);
      cont.run('envB', onElse: (e) => second = e);

      expect(first, equals('err+envA'));
      expect(second, equals('err+envB'));
    });
  });

  group('Cont.elseZipWithEnv0', () {
    test('receives environment only', () {
      String? result;

      Cont.error<String, String, int>('err')
          .elseZipWithEnv0(
            (env) => Cont.error<String, String, int>(env),
            (a, b) => '$a+$b',
          )
          .run('myEnv', onElse: (e) => result = e);

      expect(result, equals('err+myEnv'));
    });
  });
}
