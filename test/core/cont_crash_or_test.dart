import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('CrashOr', () {
    test(
        'tryCatch returns ValueCrashOr when nothing throws',
        () {
      final result = ContCrash.tryCatch(() => 42);

      final text = switch (result) {
        ValueCrashOr(value: final value) => 'value $value',
        CrashCrashOr(crash: final crash) => 'crash $crash',
      };

      expect(text, equals('value 42'));
    });

    test(
        'tryCatch returns CrashCrashOr when the function throws',
        () {
      final result =
          ContCrash.tryCatch<int>(() => throw 'boom');

      expect(result, isA<CrashCrashOr<int>>());
      expect(
        (result as CrashCrashOr<int>).crash.error,
        equals('boom'),
      );
    });

    test('equality is symmetric across type arguments', () {
      final CrashOr<int> a =
          ContCrash.tryCatch<int>(() => 1);
      final CrashOr<num> b =
          ContCrash.tryCatch<num>(() => 1);

      expect(a == b, equals(b == a));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a value and a crash are never equal', () {
      final crash = switch (
          ContCrash.tryCatch<void>(() => throw 'x')) {
        CrashCrashOr(crash: final crash) => crash,
        ValueCrashOr() =>
          throw StateError('expected a crash'),
      };
      final asValue =
          ContCrash.tryCatch<NormalCrash>(() => crash);
      final asCrash =
          ContCrash.tryCatch<NormalCrash>(() => throw 'x');

      expect(asValue, isNot(equals(asCrash)));
    });
  });
}
