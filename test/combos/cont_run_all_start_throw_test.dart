import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

// Running a Cont through a wider environment type makes runWith
// throw a TypeError while the input starts.
final Cont<Object?, String, int> _throwsOnStart =
    Cont.of<int, String, int>(1);

void main() {
  group('runAll: an input that throws while starting', () {
    test('both waits for the other side and favors else',
        () {
      String? error;
      ContCrash? crash;

      Cont.both<Object?, String, int, int, int>(
        _throwsOnStart,
        Cont.error('E'),
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a$b',
          shouldFavorCrash: false,
        ),
      ).run(
        'env',
        onElse: (e) => error = e,
        onCrash: (c) => crash = c,
      );

      expect(error, equals('E'));
      expect(crash, isNull);
    });

    test('both favors the crash when asked', () {
      ContCrash? crash;

      Cont.both<Object?, String, int, int, int>(
        _throwsOnStart,
        Cont.error('E'),
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a$b',
          shouldFavorCrash: true,
        ),
      ).run('env', onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
    });

    test('both merges two crashes', () {
      ContCrash? crash;

      Cont.both<Object?, String, int, int, int>(
        _throwsOnStart,
        _throwsOnStart,
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a$b',
          shouldFavorCrash: false,
        ),
      ).run('env', onCrash: (c) => crash = c);

      expect(crash, isA<MergedCrash>());
    });

    test('either waits for the other side and favors then',
        () {
      int? value;
      ContCrash? crash;

      Cont.either<Object?, String, String, String, int>(
        _throwsOnStart,
        Cont.of(5),
        (a, b) => '$a$b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(
        'env',
        onThen: (v) => value = v,
        onCrash: (c) => crash = c,
      );

      expect(value, equals(5));
      expect(crash, isNull);
    });

    test('either merges two crashes', () {
      ContCrash? crash;

      Cont.either<Object?, String, String, String, int>(
        _throwsOnStart,
        _throwsOnStart,
        (a, b) => '$a$b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run('env', onCrash: (c) => crash = c);

      expect(crash, isA<MergedCrash>());
    });
  });
}
