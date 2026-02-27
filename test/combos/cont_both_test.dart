import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.both (sequence)', () {
    test('combines two values', () {
      String? result;

      Cont.both<(), String, int, int, String>(
        Cont.of(1),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals('1+2'));
    });

    test('executes sequentially', () {
      final log = <String>[];

      Cont.both<(), String, int, int, String>(
        Cont.fromRun((runtime, observer) {
          log.add('left');
          observer.onThen(1);
        }),
        Cont.fromRun((runtime, observer) {
          log.add('right');
          observer.onThen(2);
        }),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run(());

      expect(log, equals(['left', 'right']));
    });

    test('terminates on left failure', () {
      String? error;

      Cont.both<(), String, int, int, String>(
        Cont.error('left failed'),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('left failed'));
    });

    test('terminates on right failure', () {
      String? error;

      Cont.both<(), String, int, int, String>(
        Cont.of(1),
        Cont.error('right failed'),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('right failed'));
    });
  });

  group('Cont.both (runAll)', () {
    test('combines two values', () {
      String? result;

      Cont.both<(), String, int, int, String>(
        Cont.of(1),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.runAll(
          (a, b) => '$a,$b',
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (v) => result = v);

      expect(result, equals('1+2'));
    });

    test('merges errors when both fail', () {
      String? error;

      Cont.both<(), String, int, int, String>(
        Cont.error('left'),
        Cont.error('right'),
        (a, b) => '$a+$b',
        policy: OkPolicy.runAll(
          (a, b) => '$a,$b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('left,right'));
    });

    test('terminates when only left fails', () {
      String? error;

      Cont.both<(), String, int, int, String>(
        Cont.error('left failed'),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.runAll(
          (a, b) => '$a,$b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('left failed'));
    });
  });

  group('Cont.both (quitFast)', () {
    test('combines two values', () {
      String? result;

      Cont.both<(), String, int, int, String>(
        Cont.of(1),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals('1+2'));
    });

    test('terminates on first failure', () {
      String? error;

      Cont.both<(), String, int, int, String>(
        Cont.error('first failed'),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('first failed'));
    });
  });

  group('Cont.and', () {
    test('wraps Cont.both as instance method', () {
      String? result;

      Cont.of<(), String, int>(1)
          .and(Cont.of(2), (a, b) => '$a+$b',
              policy: OkPolicy.sequence())
          .run((), onThen: (v) => result = v);

      expect(result, equals('1+2'));
    });

    test('supports multiple policies', () {
      String? seqResult;
      String? qfResult;

      final left = Cont.of<(), String, int>(3);
      final right = Cont.of<(), String, int>(4);

      left
          .and(right, (a, b) => '$a+$b',
              policy: OkPolicy.sequence())
          .run((), onThen: (v) => seqResult = v);

      left
          .and(right, (a, b) => '$a+$b',
              policy: OkPolicy.quitFast())
          .run((), onThen: (v) => qfResult = v);

      expect(seqResult, equals('3+4'));
      expect(qfResult, equals('3+4'));
    });

    test('supports Cont<E, F, Never> operands', () {
      String? error;

      Cont.error<(), String, Never>('never value')
          .and(Cont.of<(), String, int>(1),
              (a, b) => '$a+$b',
              policy: OkPolicy.sequence())
          .run((), onElse: (e) => error = e);

      expect(error, equals('never value'));
    });
  });
}
