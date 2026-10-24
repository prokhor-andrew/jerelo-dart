import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenZip', () {
    test('combines values from both continuations', () {
      String? result;

      Cont.of<(), String, int>(10)
          .thenZip(
        (v) => Cont.of(v * 2),
        (a, b) => '$a+$b',
      )
          .run((), onThen: (v) => result = v);

      expect(result, equals('10+20'));
    });

    test('passes through error', () {
      String? error;

      Cont.error<(), String, int>('oops')
          .thenZip(
        (v) => Cont.of(v * 2),
        (a, b) => a + b,
      )
          .run((), onElse: (e) => error = e);

      expect(error, equals('oops'));
    });

    test('propagates error from zipped continuation', () {
      String? error;

      Cont.of<(), String, int>(10)
          .thenZip(
        (_) => Cont.error<(), String, int>('zip failed'),
        (a, b) => a + b,
      )
          .run((), onElse: (e) => error = e);

      expect(error, equals('zip failed'));
    });

    test('can be run multiple times', () {
      final cont = Cont.of<(), String, int>(5).thenZip(
        (v) => Cont.of(v + 1),
        (a, b) => a + b,
      );

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(11));
      expect(second, equals(11));
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(10)
          .thenZip<int, int>(
        (v) => throw Exception('boom'),
        (a, b) => a + b,
      )
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.thenZip0', () {
    test('combines values ignoring source value in factory',
        () {
      String? result;

      Cont.of<(), String, int>(10)
          .thenZip0(
        () => Cont.of(99),
        (a, b) => '$a+$b',
      )
          .run((), onThen: (v) => result = v);

      expect(result, equals('10+99'));
    });
  });
}
