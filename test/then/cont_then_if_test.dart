import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenIf', () {
    test('passes through when predicate is true', () {
      int? result;

      Cont.of<(), String, int>(42)
          .thenIf((v) => v > 0, fallback: 'negative')
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('terminates with fallback when predicate is false',
        () {
      String? error;

      Cont.of<(), String, int>(-1)
          .thenIf((v) => v > 0, fallback: 'negative')
          .run((), onElse: (e) => error = e);

      expect(error, equals('negative'));
    });

    test('passes through error unchanged', () {
      String? error;

      Cont.error<(), String, int>('original')
          .thenIf((v) => v > 0, fallback: 'fallback')
          .run((), onElse: (e) => error = e);

      expect(error, equals('original'));
    });

    test('can be run multiple times', () {
      final cont = Cont.of<(), String, int>(5)
          .thenIf((v) => v > 0, fallback: 'nope');

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(5));
      expect(second, equals(5));
    });

    test('crashes when predicate throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42)
          .thenIf((_) => throw Exception('boom'),
              fallback: 'x')
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.thenIf0', () {
    test('passes through when predicate is true', () {
      int? result;

      Cont.of<(), String, int>(42)
          .thenIf0(() => true, fallback: 'nope')
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('terminates with fallback when predicate is false',
        () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenIf0(() => false, fallback: 'fallback')
          .run((), onElse: (e) => error = e);

      expect(error, equals('fallback'));
    });
  });
}
