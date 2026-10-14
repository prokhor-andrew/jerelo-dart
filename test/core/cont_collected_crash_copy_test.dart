import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

ContCrash _crashOf(Object error) {
  return switch (ContCrash.tryCatch<void>(() {
    throw error;
  })) {
    CrashCrashOr(crash: final crash) => crash,
    ValueCrashOr() => throw StateError('expected a crash'),
  };
}

void main() {
  group('ContCrash.collect', () {
    test('keeps its own copy of the map', () {
      final source = <int, ContCrash>{0: _crashOf('a')};
      final collected =
          ContCrash.collect(source) as CollectedCrash;
      final hashBefore = collected.hashCode;

      source[1] = _crashOf('b');

      expect(collected.crashes.length, equals(1));
      expect(collected.hashCode, equals(hashBefore));
    });

    test('exposes an unmodifiable map', () {
      final collected =
          ContCrash.collect({0: _crashOf('a')})
              as CollectedCrash;

      expect(
        () => collected.crashes[1] = _crashOf('b'),
        throwsUnsupportedError,
      );
    });

    test('a combinator result is unmodifiable too', () {
      ContCrash? crash;
      Cont.all<(), String, int>(
        [
          Cont.crash(_crashOf('a')),
          Cont.crash(_crashOf('b'))
        ],
        policy: OkPolicy.runAll(
          (a, b) => '$a$b',
          shouldFavorCrash: true,
        ),
      ).run((), onCrash: (c) => crash = c);

      expect(
        () => (crash! as CollectedCrash).crashes.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
