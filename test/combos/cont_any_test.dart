import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.any (sequence)', () {
    test('returns first success', () {
      int? value;

      Cont.any<(), String, int>(
        [
          Cont.error('err'),
          Cont.of(20),
          Cont.of(30),
        ],
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('does not execute past first success', () {
      bool thirdCalled = false;

      Cont.any<(), String, int>([
        Cont.error('err'),
        Cont.of(20),
        Cont.fromRun((runtime, observer) {
          thirdCalled = true;
          observer.onThen(30);
        }),
      ], policy: OkPolicy.sequence()).run(());

      expect(thirdCalled, false);
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

      expect(errors!.length, 3);
      expect(errors, ['err1', 'err2', 'err3']);
    });

    test('handles empty list', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [],
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, isNotNull);
      expect(errors, isEmpty);
    });
  });

  group('Cont.any (runAll)', () {
    test('combines values when multiple succeed', () {
      int? value;

      Cont.any<(), String, int>(
        [Cont.of(10), Cont.of(20), Cont.of(30)],
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 60);
    });

    test('returns single success when others fail', () {
      int? value;

      Cont.any<(), String, int>(
        [
          Cont.error('err1'),
          Cont.of(20),
          Cont.error('err3'),
        ],
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('collects all errors when all fail', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [
          Cont.error('err1'),
          Cont.error('err2'),
        ],
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors, ['err1', 'err2']);
    });
  });

  group('Cont.any (quitFast)', () {
    test('returns first success', () {
      int? value;

      Cont.any<(), String, int>(
        [Cont.of(10), Cont.of(20)],
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test('terminates when all fail', () {
      List<String>? errors;

      Cont.any<(), String, int>(
        [
          Cont.error('err1'),
          Cont.error('err2'),
        ],
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, isNotNull);
    });
  });

  group('Cont.any shared', () {
    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.any<(), String, int>([
        Cont.fromRun((runtime, observer) {
          callCount++;
          observer.onThen(callCount);
        }),
      ], policy: OkPolicy.sequence());

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 1);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 2);
      expect(callCount, 2);
    });
  });
}
