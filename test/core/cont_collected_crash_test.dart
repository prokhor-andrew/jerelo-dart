import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

NormalCrash crashOf(Object error) {
  return ContCrash.tryCatch<void>(() {
    throw error;
  }).match(
    (_) => throw StateError('expected a crash'),
    (crash) => crash,
  );
}

void main() {
  group('CollectedCrash equality', () {
    test('equal when maps have equal entries', () {
      final a = CollectedCrash(
          {0: crashOf('x'), 1: crashOf('y')});
      final b = CollectedCrash(
          {0: crashOf('x'), 1: crashOf('y')});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ignores insertion order', () {
      final a = CollectedCrash(
          {0: crashOf('x'), 1: crashOf('y')});
      final b = CollectedCrash(
          {1: crashOf('y'), 0: crashOf('x')});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('empty crashes are equal', () {
      expect(
        const CollectedCrash({}),
        equals(CollectedCrash(<int, ContCrash>{})),
      );
    });

    test('not equal when a value differs', () {
      final a = CollectedCrash({0: crashOf('x')});
      final b = CollectedCrash({0: crashOf('y')});

      expect(a, isNot(equals(b)));
    });

    test('not equal when a key differs', () {
      final a = CollectedCrash({0: crashOf('x')});
      final b = CollectedCrash({1: crashOf('x')});

      expect(a, isNot(equals(b)));
    });

    test('not equal when one has extra entries', () {
      final a = CollectedCrash({0: crashOf('x')});
      final b = CollectedCrash(
          {0: crashOf('x'), 1: crashOf('y')});

      expect(a, isNot(equals(b)));
      expect(b, isNot(equals(a)));
    });

    test('compares nested crashes by value', () {
      final a = CollectedCrash({
        0: MergedCrash(crashOf('x'), crashOf('y')),
        1: CollectedCrash({0: crashOf('z')}),
      });
      final b = CollectedCrash({
        0: MergedCrash(crashOf('x'), crashOf('y')),
        1: CollectedCrash({0: crashOf('z')}),
      });

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal to other crash types', () {
      final crash = crashOf('x');

      expect(
          CollectedCrash({0: crash}), isNot(equals(crash)));
      expect(
        CollectedCrash({0: crash}),
        isNot(equals(MergedCrash(crash, crash))),
      );
    });

    test('equal crashes reported by converge compare equal',
        () {
      ContCrash? first;
      ContCrash? second;

      Cont<(), String, int> crashing(String error) {
        return Cont.of<(), String, int>(0).thenDo<int>((_) {
          throw error;
        });
      }

      final program = Cont.converge<(), String, int>(
        [crashing('a'), crashing('b')],
        policy: CrashPolicy.sequence<String, int>(),
      );

      program.run((), onCrash: (c) => first = c);
      program.run((), onCrash: (c) => second = c);

      expect(first, isA<CollectedCrash>());
      expect(first, equals(second));
    });
  });
}
