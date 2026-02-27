import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.local', () {
    test('transforms environment', () {
      int? captured;

      Cont.askThen<int, Never>()
          .local<String>((env) => env.length)
          .run('hello', onThen: (v) => captured = v);

      expect(captured, equals(5));
    });

    test('preserves value', () {
      int? result;

      Cont.of<int, Never, int>(42)
          .local<String>((env) => env.length)
          .run('hello', onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('preserves error', () {
      String? error;

      Cont.error<int, String, int>('oops')
          .local<String>((env) => env.length)
          .run('hello', onElse: (e) => error = e);

      expect(error, equals('oops'));
    });

    test('supports chaining', () {
      int? result;

      Cont.askThen<int, Never>()
          .local<String>((env) => env.length)
          .thenMap((v) => v * 2)
          .run('hello', onThen: (v) => result = v);

      expect(result, equals(10));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont = Cont.askThen<int, Never>()
          .local<String>((env) => env.length);

      cont.run('hi', onThen: (v) => first = v);
      cont.run('hello', onThen: (v) => second = v);

      expect(first, equals(2));
      expect(second, equals(5));
    });
  });

  group('Cont.local0', () {
    test('provides constant environment', () {
      int? result;

      Cont.askThen<int, Never>()
          .local0<String>(() => 42)
          .run('ignored', onThen: (v) => result = v);

      expect(result, equals(42));
    });
  });

  group('Cont.withEnv', () {
    test('provides fixed environment', () {
      int? result;

      Cont.askThen<int, Never>()
          .withEnv<String>(99)
          .run('ignored', onThen: (v) => result = v);

      expect(result, equals(99));
    });
  });
}
