import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

NormalCrash crashOf(Object error) {
  return switch (ContCrash.tryCatch<void>(() {
    throw error;
  })) {
    CrashCrashOr(crash: final crash) => crash,
    ValueCrashOr() => throw StateError('expected a crash'),
  };
}

void main() {
  group('CollectedCrash equality', () {
    test('equal when maps have equal entries', () {
      final a = ContCrash.collect(
          {0: crashOf('x'), 1: crashOf('y')});
      final b = ContCrash.collect(
          {0: crashOf('x'), 1: crashOf('y')});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ignores insertion order', () {
      final a = ContCrash.collect(
          {0: crashOf('x'), 1: crashOf('y')});
      final b = ContCrash.collect(
          {1: crashOf('y'), 0: crashOf('x')});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('empty crashes are equal', () {
      expect(
        ContCrash.collect({}),
        equals(ContCrash.collect(<int, ContCrash>{})),
      );
    });

    test('not equal when a value differs', () {
      final a = ContCrash.collect({0: crashOf('x')});
      final b = ContCrash.collect({0: crashOf('y')});

      expect(a, isNot(equals(b)));
    });

    test('not equal when a key differs', () {
      final a = ContCrash.collect({0: crashOf('x')});
      final b = ContCrash.collect({1: crashOf('x')});

      expect(a, isNot(equals(b)));
    });

    test('not equal when one has extra entries', () {
      final a = ContCrash.collect({0: crashOf('x')});
      final b = ContCrash.collect(
          {0: crashOf('x'), 1: crashOf('y')});

      expect(a, isNot(equals(b)));
      expect(b, isNot(equals(a)));
    });

    test('compares nested crashes by value', () {
      final a = ContCrash.collect({
        0: ContCrash.merge(crashOf('x'), crashOf('y')),
        1: ContCrash.collect({0: crashOf('z')}),
      });
      final b = ContCrash.collect({
        0: ContCrash.merge(crashOf('x'), crashOf('y')),
        1: ContCrash.collect({0: crashOf('z')}),
      });

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal to other crash types', () {
      final crash = crashOf('x');

      expect(ContCrash.collect({0: crash}),
          isNot(equals(crash)));
      expect(
        ContCrash.collect({0: crash}),
        isNot(equals(ContCrash.merge(crash, crash))),
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
        policy: CrashPolicy.sequence(),
      );

      program.run((), onCrash: (c) => first = c);
      program.run((), onCrash: (c) => second = c);

      expect(first, isA<CollectedCrash>());
      expect(first, equals(second));
    });
  });
}
