import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.promote', () {
    test('recovers from error with computed value', () {
      int? result;

      Cont.error<(), String, int>('42')
          .promote((e) => int.parse(e))
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('receives original error', () {
      String? captured;
      int? result;

      Cont.error<(), String, int>('hello').promote((e) {
        captured = e;
        return 0;
      }).run((), onThen: (v) => result = v);

      expect(captured, equals('hello'));
      expect(result, equals(0));
    });

    test('passes through value', () {
      bool called = false;
      int? result;

      Cont.of<(), String, int>(42).promote((e) {
        called = true;
        return 0;
      }).run((), onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('oops')
          .promote((_) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont = Cont.error<(), String, int>('42')
          .promote((e) => int.parse(e));

      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
    });
  });

  group('Cont.promote0', () {
    test('recovers ignoring error value', () {
      int? result;

      Cont.error<(), String, int>('anything')
          .promote0(() => 99)
          .run((), onThen: (v) => result = v);

      expect(result, equals(99));
    });
  });

  group('Cont.promoteWith', () {
    test('recovers with constant value', () {
      int? result;

      Cont.error<(), String, int>('anything')
          .promoteWith(42)
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });
  });
}
