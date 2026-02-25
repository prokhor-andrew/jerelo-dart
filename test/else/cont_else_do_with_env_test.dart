import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDoWithEnv', () {
    test('receives environment and error', () {
      String? received;

      Cont.error<String, String, int>('err')
          .elseDoWithEnv((env, error) {
        received = '$env: $error';
        return Cont.of(42);
      }).run('hello', onThen: (_) {});

      expect(received, 'hello: err');
    });

    test('passes through value path', () {
      bool chainCalled = false;
      int? value;

      Cont.of<String, String, int>(42)
          .elseDoWithEnv<String>((env, error) {
        chainCalled = true;
        return Cont.of(0);
      }).run('hello', onThen: (val) => value = val);

      expect(chainCalled, false);
      expect(value, 42);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.error<String, String, int>('err')
          .elseDoWithEnv((env, error) {
        callCount++;
        return Cont.of(callCount);
      });

      int? value1;
      cont.run('env1', onThen: (val) => value1 = val);
      expect(value1, 1);
      expect(callCount, 1);

      int? value2;
      cont.run('env2', onThen: (val) => value2 = val);
      expect(value2, 2);
      expect(callCount, 2);
    });
  });

  group('Cont.elseDoWithEnv0', () {
    test('receives environment only', () {
      String? received;

      Cont.error<String, String, int>('err')
          .elseDoWithEnv0((env) {
        received = 'env: $env';
        return Cont.of(42);
      }).run('hello', onThen: (_) {});

      expect(received, 'env: hello');
    });
  });
}
