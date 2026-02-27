import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.all (sequence)', () {
    test('collects all values in order', () {
      List<int>? result;

      Cont.all<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals([1, 2, 3]));
    });

    test('executes sequentially', () {
      final log = <int>[];

      Cont.all<(), String, int>(
        [
          Cont.fromRun((runtime, observer) {
            log.add(1);
            observer.onThen(1);
          }),
          Cont.fromRun((runtime, observer) {
            log.add(2);
            observer.onThen(2);
          }),
          Cont.fromRun((runtime, observer) {
            log.add(3);
            observer.onThen(3);
          }),
        ],
        policy: OkPolicy.sequence(),
      ).run(());

      expect(log, equals([1, 2, 3]));
    });

    test('stops at first failure', () {
      int executed = 0;
      String? error;

      Cont.all<(), String, int>(
        [
          Cont.fromRun((runtime, observer) {
            executed++;
            observer.onThen(1);
          }),
          Cont.error('failed'),
          Cont.fromRun((runtime, observer) {
            executed++;
            observer.onThen(3);
          }),
        ],
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(executed, equals(1));
      expect(error, equals('failed'));
    });

    test('succeeds with empty list', () {
      List<int>? result;

      Cont.all<(), String, int>(
        [],
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals([]));
    });
  });

  group('Cont.all (runAll)', () {
    test('collects all values', () {
      List<int>? result;

      Cont.all<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: OkPolicy.runAll(
          (a, b) => '$a,$b',
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (v) => result = v);

      expect(result, equals([1, 2, 3]));
    });

    test('combines errors from multiple failures', () {
      String? error;

      Cont.all<(), String, int>(
        [
          Cont.error('error1'),
          Cont.of(2),
          Cont.error('error2'),
        ],
        policy: OkPolicy.runAll(
          (a, b) => '$a,$b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, isNotNull);
    });
  });

  group('Cont.all (quitFast)', () {
    test('collects all values', () {
      List<int>? result;

      Cont.all<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals([1, 2, 3]));
    });

    test('terminates on first failure', () {
      String? error;

      Cont.all<(), String, int>(
        [
          Cont.error('first'),
          Cont.of(2),
        ],
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, isNotNull);
    });
  });

  group('Cont.all shared', () {
    test('supports multiple runs', () {
      int? firstRun;
      int? secondRun;

      final list = [
        Cont.of<(), String, int>(1),
        Cont.of<(), String, int>(2)
      ];
      final cont = Cont.all<(), String, int>(list,
          policy: OkPolicy.sequence());

      cont.run((), onThen: (v) => firstRun = v.length);
      cont.run((), onThen: (v) => secondRun = v.length);

      expect(firstRun, equals(2));
      expect(secondRun, equals(2));
    });
  });
}
