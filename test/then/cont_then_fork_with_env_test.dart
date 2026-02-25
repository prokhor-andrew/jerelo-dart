import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenForkWithEnv', () {
    test('receives environment and value', () {
      String? received;
      int? value;

      Cont.of<String, String, int>(42)
          .thenForkWithEnv((env, a) {
            received = '$env: $a';
            return Cont.of('side');
          })
          .run('hello', onThen: (val) => value = val);

      expect(received, 'hello: 42');
      expect(value, 42);
    });

    test('passes through error', () {
      bool forkCalled = false;
      String? error;

      Cont.error<String, String, int>('err')
          .thenForkWithEnv<String, String>((env, a) {
            forkCalled = true;
            return Cont.of('side');
          })
          .run('hello', onElse: (e) => error = e);

      expect(forkCalled, false);
      expect(error, 'err');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.of<String, String, int>(5).thenForkWithEnv((env, a) {
        callCount++;
        return Cont.of('ok');
      });

      cont.run('env1');
      expect(callCount, 1);

      cont.run('env2');
      expect(callCount, 2);
    });
  });

  group('Cont.thenForkWithEnv0', () {
    test('receives environment only', () {
      String? received;
      int? value;

      Cont.of<String, String, int>(42)
          .thenForkWithEnv0((env) {
            received = 'env: $env';
            return Cont.of('side');
          })
          .run('hello', onThen: (val) => value = val);

      expect(received, 'env: hello');
      expect(value, 42);
    });
  });
}
