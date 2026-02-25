import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTapWithEnv', () {
    test('receives environment and error, promotes on success', () {
      String? received;
      int? value;

      Cont.error<String, String, int>('err')
          .elseTapWithEnv((env, e) {
            received = '$env: $e';
            return Cont.of(99);
          })
          .run('hello', onThen: (val) => value = val);

      expect(received, 'hello: err');
      expect(value, 99);
    });

    test('passes through value', () {
      bool tapCalled = false;
      int? value;

      Cont.of<String, String, int>(42)
          .elseTapWithEnv<String>((env, e) {
            tapCalled = true;
            return Cont.of(99);
          })
          .run('hello', onThen: (val) => value = val);

      expect(tapCalled, false);
      expect(value, 42);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.error<String, String, int>('err').elseTapWithEnv((env, e) {
        callCount++;
        return Cont.of(99);
      });

      cont.run('env1');
      expect(callCount, 1);

      cont.run('env2');
      expect(callCount, 2);
    });
  });

  group('Cont.elseTapWithEnv0', () {
    test('receives environment only, promotes on success', () {
      String? received;
      int? value;

      Cont.error<String, String, int>('err')
          .elseTapWithEnv0((env) {
            received = 'env: $env';
            return Cont.of(99);
          })
          .run('hello', onThen: (val) => value = val);

      expect(received, 'env: hello');
      expect(value, 99);
    });
  });
}
