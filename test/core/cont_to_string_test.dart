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
  group('toString uses the constructor style', () {
    test('TailRec', () {
      expect(
        TailRec.next<int, String>(1).toString(),
        equals('NextTailRec(1)'),
      );
      expect(
        TailRec.done<int, String>('x').toString(),
        equals('DoneTailRec(x)'),
      );
    });

    test('CrashOr', () {
      expect(
        ContCrash.tryCatch(() => 42).toString(),
        equals('ValueCrashOr(42)'),
      );
      final crash = crashOf('boom');
      expect(
        ContCrash.tryCatch<int>(() => throw 'boom')
            .toString(),
        startsWith('CrashCrashOr(NormalCrash(boom, '),
      );
      expect(crash.toString(),
          startsWith('NormalCrash(boom, '));
    });

    test('crash types', () {
      final a = crashOf('a');
      final b = crashOf('b');

      expect(
        ContCrash.merge(a, b).toString(),
        equals('MergedCrash($a, $b)'),
      );
      expect(
        ContCrash.collect({0: a}).toString(),
        equals('CollectedCrash({0: $a})'),
      );
    });
  });
}
