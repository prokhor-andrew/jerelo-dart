import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseUnless', () {
    test('recovers to fallback when predicate is false',
        () {
      int? result;

      Cont.error<(), String, int>('not found')
          .elseUnless((e) => e == 'fatal', fallback: 42)
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('keeps error when predicate is true', () {
      String? error;

      Cont.error<(), String, int>('fatal')
          .elseUnless((e) => e == 'fatal', fallback: 0)
          .run((), onElse: (e) => error = e);

      expect(error, equals('fatal'));
    });

    test('passes through value unchanged', () {
      int? result;
      bool called = false;

      Cont.of<(), String, int>(42).elseUnless((_) {
        called = true;
        return false;
      }, fallback: 0).run((), onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont = Cont.error<(), String, int>('err')
          .elseUnless((_) => false, fallback: 99);

      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(99));
      expect(second, equals(99));
    });

    test('crashes when predicate throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('oops')
          .elseUnless((_) => throw Exception('boom'),
              fallback: 0)
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.elseUnless0', () {
    test('recovers when zero-arg predicate is false', () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseUnless0(() => false, fallback: 42)
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('keeps error when zero-arg predicate is true', () {
      String? error;

      Cont.error<(), String, int>('fatal')
          .elseUnless0(() => true, fallback: 0)
          .run((), onElse: (e) => error = e);

      expect(error, equals('fatal'));
    });
  });
}
