import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDoWithEnv', () {
    test('receives environment and value', () {
      String? received;

      Cont.of<String, String, int>(10)
          .thenDoWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onThen: (val) => received = val);

      expect(received, 'hello: 10');
    });

    test('passes through error', () {
      bool chainCalled = false;
      String? error;

      Cont.error<String, String, int>('err')
          .thenDoWithEnv<int>((env, a) {
            chainCalled = true;
            return Cont.of(a * 2);
          })
          .run('hello', onElse: (e) => error = e);

      expect(chainCalled, false);
      expect(error, 'err');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.of<String, String, int>(5).thenDoWithEnv((env, a) {
        callCount++;
        return Cont.of('$env: $a');
      });

      String? value1;
      cont.run('env1', onThen: (val) => value1 = val);
      expect(value1, 'env1: 5');
      expect(callCount, 1);

      String? value2;
      cont.run('env2', onThen: (val) => value2 = val);
      expect(value2, 'env2: 5');
      expect(callCount, 2);
    });
  });

  group('Cont.thenDoWithEnv0', () {
    test('receives environment only', () {
      String? received;

      Cont.of<String, String, int>(10)
          .thenDoWithEnv0((env) => Cont.of('env: $env'))
          .run('hello', onThen: (val) => received = val);

      expect(received, 'env: hello');
    });
  });
}
