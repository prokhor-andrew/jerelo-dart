import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.any (sequence)', () {
    test('returns first success', () {
      int? result;

      Cont.any<(), String, int>(
        [Cont.error('err1'), Cont.of(42), Cont.of(99)],
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('does not execute past first success', () {
      int executed = 0;

      Cont.any<(), String, int>(
        [
          Cont.error('err'),
          Cont.fromRun((runtime, observer) {
            executed++;
            observer.onThen(42);
          }),
          Cont.fromRun((runtime, observer) {
            executed++;
            observer.onThen(99);
          }),
        ],
        policy: OkPolicy.sequence(),
      ).run(());

      expect(executed, equals(1));
    });

    test('collects all errors when all fail', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [
          Cont.error('err1'),
          Cont.error('err2'),
          Cont.error('err3'),
        ],
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, equals(['err1', 'err2', 'err3']));
    });

    test('handles empty list', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [],
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, equals([]));
    });
  });

  group('Cont.any (runAll)', () {
    test('combines values when multiple succeed', () {
      int? result;

      Cont.any<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.error('err')],
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(3));
    });

    test('returns single success when others fail', () {
      int? result;

      Cont.any<(), String, int>(
        [
          Cont.error('err1'),
          Cont.of(42),
          Cont.error('err2')
        ],
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('collects all errors when all fail', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [Cont.error('err1'), Cont.error('err2')],
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => errors = e);

      expect(errors, isNotNull);
    });
  });

  group('Cont.any (quitFast)', () {
    test('returns first success', () {
      int? result;

      Cont.any<(), String, int>(
        [Cont.error('err'), Cont.of(42)],
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => result = v);

      expect(result, isNotNull);
    });

    test('terminates when all fail', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [Cont.error('err1'), Cont.error('err2')],
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, isNotNull);
    });
  });

  group('Cont.any shared', () {
    test('supports multiple runs', () {
      int? firstRun;
      int? secondRun;

      final cont = Cont.any<(), String, int>(
        [Cont.of(42)],
        policy: OkPolicy.sequence(),
      );

      cont.run((), onThen: (v) => firstRun = v);
      cont.run((), onThen: (v) => secondRun = v);

      expect(firstRun, equals(42));
      expect(secondRun, equals(42));
    });
  });
}
