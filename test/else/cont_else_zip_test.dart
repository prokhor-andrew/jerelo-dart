import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseZip', () {
    test('combines errors from both continuations', () {
      String? error;

      Cont.error<(), String, int>('first')
          .elseZip(
        (_) => Cont.error<(), String, int>('second'),
        (a, b) => '$a+$b',
      )
          .run((), onElse: (e) => error = e);

      expect(error, equals('first+second'));
    });

    test('passes through value', () {
      int? result;
      bool called = false;

      Cont.of<(), String, int>(42).elseZip(
        (_) {
          called = true;
          return Cont.error<(), String, int>('oops');
        },
        (a, b) => '$a+$b',
      ).run((), onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('recovers when zipped continuation succeeds', () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseZip(
        (_) => Cont.of<(), String, int>(42),
        (a, b) => '$a+$b',
      )
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('can be run multiple times', () {
      String? first;
      String? second;

      final cont =
          Cont.error<(), String, int>('err').elseZip(
        (_) => Cont.error<(), String, int>('fallback'),
        (a, b) => '$a+$b',
      );

      cont.run((), onElse: (e) => first = e);
      cont.run((), onElse: (e) => second = e);

      expect(first, equals('err+fallback'));
      expect(second, equals('err+fallback'));
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('oops')
          .elseZip<String, String>(
        (_) => throw Exception('boom'),
        (a, b) => '$a+$b',
      )
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.elseZip0', () {
    test('combines errors ignoring source error in factory',
        () {
      String? error;

      Cont.error<(), String, int>('first')
          .elseZip0(
        () => Cont.error<(), String, int>('second'),
        (a, b) => '$a+$b',
      )
          .run((), onElse: (e) => error = e);

      expect(error, equals('first+second'));
    });
  });
}
