import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenTapWithEnv', () {
    test('receives environment and value', () {
      String? received;
      int? value;

      Cont.of<String, String, int>(42)
          .thenTapWithEnv((env, a) {
            received = '$env: $a';
            return Cont.of('side');
          })
          .run('hello', onThen: (val) => value = val);

      expect(received, 'hello: 42');
      expect(value, 42);
    });

    test('passes through error', () {
      bool tapCalled = false;
      String? error;

      Cont.error<String, String, int>('err')
          .thenTapWithEnv<String>((env, a) {
            tapCalled = true;
            return Cont.of('side');
          })
          .run('hello', onElse: (e) => error = e);

      expect(tapCalled, false);
      expect(error, 'err');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.of<String, String, int>(5).thenTapWithEnv((env, a) {
        callCount++;
        return Cont.of('ok');
      });

      cont.run('env1');
      expect(callCount, 1);

      cont.run('env2');
      expect(callCount, 2);
    });
  });

  group('Cont.thenTapWithEnv0', () {
    test('receives environment only', () {
      String? received;
      int? value;

      Cont.of<String, String, int>(42)
          .thenTapWithEnv0((env) {
            received = 'env: $env';
            return Cont.of('side');
          })
          .run('hello', onThen: (val) => value = val);

      expect(received, 'env: hello');
      expect(value, 42);
    });
  });
}
