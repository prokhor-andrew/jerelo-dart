import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseZipWithEnv', () {
    test('receives environment and error', () {
      String? error;

      Cont.error<String, String, int>('err1')
          .elseZipWithEnv(
            (env, e) =>
                Cont.error<String, String, int>('$env: $e'),
            (a, b) => '$a + $b',
          )
          .run('hello', onElse: (e) => error = e);

      expect(error, 'err1 + hello: err1');
    });

    test('passes through value', () {
      bool zipCalled = false;
      int? value;

      Cont.of<String, String, int>(42)
          .elseZipWithEnv<String, String>(
        (env, e) {
          zipCalled = true;
          return Cont.error('err2');
        },
        (a, b) => '$a + $b',
      ).run('hello', onThen: (val) => value = val);

      expect(zipCalled, false);
      expect(value, 42);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.error<String, String, int>('err1')
          .elseZipWithEnv(
        (env, e) {
          callCount++;
          return Cont.error<String, String, int>('err2');
        },
        (a, b) => '$a + $b',
      );

      String? error1;
      cont.run('env1', onElse: (e) => error1 = e);
      expect(error1, 'err1 + err2');
      expect(callCount, 1);

      String? error2;
      cont.run('env2', onElse: (e) => error2 = e);
      expect(error2, 'err1 + err2');
      expect(callCount, 2);
    });
  });

  group('Cont.elseZipWithEnv0', () {
    test('receives environment only', () {
      String? error;

      Cont.error<String, String, int>('err1')
          .elseZipWithEnv0(
            (env) =>
                Cont.error<String, String, int>('$env'),
            (a, b) => '$a + $b',
          )
          .run('hello', onElse: (e) => error = e);

      expect(error, 'err1 + hello');
    });
  });
}
