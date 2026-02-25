import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.local', () {
    test('transforms environment', () {
      String? value;

      Cont.askThen<int, String>()
          .thenMap((env) => 'env: $env')
          .local<String>((s) => s.length)
          .run('hello', onThen: (val) => value = val);

      expect(value, 'env: 5');
    });

    test('preserves value', () {
      int? value;

      Cont.of<int, String, int>(42)
          .local<String>((s) => s.length)
          .run('hello', onThen: (val) => value = val);

      expect(value, 42);
    });

    test('preserves error', () {
      String? error;

      Cont.error<int, String, int>('err')
          .local<String>((s) => s.length)
          .run('hello', onElse: (e) => error = e);

      expect(error, 'err');
    });

    test('supports chaining', () {
      String? value;

      Cont.askThen<int, String>()
          .thenMap((env) => 'env: $env')
          .local<String>((s) => s.length)
          .local<List<int>>((list) => list.join(','))
          .run([1, 2, 3], onThen: (val) => value = val);

      expect(value, 'env: 5');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.askThen<int, String>()
          .thenMap((env) {
            callCount++;
            return 'env: $env';
          })
          .local<String>((s) => s.length);

      String? value1;
      cont.run('hello', onThen: (val) => value1 = val);
      expect(value1, 'env: 5');
      expect(callCount, 1);

      String? value2;
      cont.run('hi', onThen: (val) => value2 = val);
      expect(value2, 'env: 2');
      expect(callCount, 2);
    });
  });

  group('Cont.local0', () {
    test('provides constant environment', () {
      String? value;

      Cont.askThen<int, String>()
          .thenMap((env) => 'env: $env')
          .local0<String>(() => 99)
          .run('ignored', onThen: (val) => value = val);

      expect(value, 'env: 99');
    });
  });

  group('Cont.withEnv', () {
    test('provides fixed environment', () {
      String? value;

      Cont.askThen<int, String>()
          .thenMap((env) => 'env: $env')
          .withEnv<String>(42)
          .run('ignored', onThen: (val) => value = val);

      expect(value, 'env: 42');
    });
  });
}
