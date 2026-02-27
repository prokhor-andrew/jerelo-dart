import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.flatten', () {
    test('unwraps nested Cont with value', () {
      int? result;

      Cont.of<(), String, Cont<(), String, int>>(
              Cont.of(42))
          .flatten()
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('unwraps nested Cont with error', () {
      String? error;

      Cont.of<(), String, Cont<(), String, int>>(
              Cont.error('inner error'))
          .flatten()
          .run((), onElse: (e) => error = e);

      expect(error, equals('inner error'));
    });

    test('passes through outer error', () {
      String? error;

      Cont.error<(), String, Cont<(), String, int>>(
              'outer error')
          .flatten()
          .run((), onElse: (e) => error = e);

      expect(error, equals('outer error'));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont =
          Cont.of<(), String, Cont<(), String, int>>(
                  Cont.of(42))
              .flatten();

      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
    });
  });
}
