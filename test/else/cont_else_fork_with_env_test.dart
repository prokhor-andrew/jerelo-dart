import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseForkWithEnv', () {
    test('receives environment and error', () {
      String? received;
      String? error;

      Cont.error<String, String, int>('err')
          .elseForkWithEnv((env, e) {
        received = '$env: $e';
        return Cont.of('side');
      }).run('hello', onElse: (e) => error = e);

      expect(received, 'hello: err');
      expect(error, 'err');
    });

    test('passes through value', () {
      bool forkCalled = false;
      int? value;

      Cont.of<String, String, int>(42)
          .elseForkWithEnv<String, String>((env, e) {
        forkCalled = true;
        return Cont.of('side');
      }).run('hello', onThen: (val) => value = val);

      expect(forkCalled, false);
      expect(value, 42);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.error<String, String, int>('err')
          .elseForkWithEnv((env, e) {
        callCount++;
        return Cont.of('ok');
      });

      cont.run('env1');
      expect(callCount, 1);

      cont.run('env2');
      expect(callCount, 2);
    });
  });

  group('Cont.elseForkWithEnv0', () {
    test('receives environment only', () {
      String? received;
      String? error;

      Cont.error<String, String, int>('err')
          .elseForkWithEnv0((env) {
        received = 'env: $env';
        return Cont.of('side');
      }).run('hello', onElse: (e) => error = e);

      expect(received, 'env: hello');
      expect(error, 'err');
    });
  });
}
