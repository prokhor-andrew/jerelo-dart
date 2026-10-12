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
  group('MergedCrash equality', () {
    test('equal crashes have equal hash codes', () {
      final a = MergedCrash(crashOf('x'), crashOf('y'));
      final b = MergedCrash(crashOf('x'), crashOf('y'));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('order matters', () {
      final a = MergedCrash(crashOf('x'), crashOf('y'));
      final b = MergedCrash(crashOf('y'), crashOf('x'));

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('equal sides do not collapse to one hash code',
        () {
      final a = MergedCrash(crashOf('x'), crashOf('x'));
      final b = MergedCrash(crashOf('y'), crashOf('y'));

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
