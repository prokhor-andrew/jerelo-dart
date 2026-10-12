import 'dart:async';

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
  group('Cont.coalesce', () {
    test('sequence runs right only if left crashes', () {
      var rightRan = false;
      int? result;

      Cont.coalesce<(), String, int>(
        Cont.of(1),
        Cont.fromRun((runtime, observer) {
          rightRan = true;
          observer.onThen(2);
        }),
        policy: CrashPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(1));
      expect(rightRan, isFalse);
    });

    test('both crashing gives a MergedCrash', () {
      ContCrash? crash;

      Cont.coalesce<(), String, int>(
        Cont.crash(crashOf('a')),
        Cont.crash(crashOf('b')),
        policy: CrashPolicy.quitFast(),
      ).run((), onCrash: (c) => crash = c);

      expect(crash,
          equals(MergedCrash(crashOf('a'), crashOf('b'))));
    });

    test('quitFast returns before the other side finishes',
        () async {
      final order = <String>[];

      Cont.coalesce<(), String, int>(
        Cont.fromRun((runtime, observer) {
          Timer(const Duration(milliseconds: 30), () {
            order.add('slow side finished');
            observer.onThen(2);
          });
        }),
        Cont.of(1),
        policy: CrashPolicy.quitFast(),
      ).run((), onThen: (v) => order.add('result $v'));

      expect(order, equals(['result 1']));
      await Future<void>.delayed(
          const Duration(milliseconds: 50));
      expect(order,
          equals(['result 1', 'slow side finished']));
    });
  });

  group('Cont.coalesceWith', () {
    test('is coalesce with this as the left side', () {
      int? result;

      Cont.crash<(), String, int>(crashOf('a'))
          .coalesceWith(Cont.of(2),
              policy: CrashPolicy.sequence())
          .run((), onThen: (v) => result = v);

      expect(result, equals(2));
    });
  });

  group('Cont.converge', () {
    test('returns the first non-crash result', () {
      int? result;

      Cont.converge<(), String, int>(
        [Cont.crash(crashOf('a')), Cont.of(2), Cont.of(3)],
        policy: CrashPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(2));
    });

    test('all crashing gives a CollectedCrash', () {
      ContCrash? crash;

      Cont.converge<(), String, int>(
        [
          Cont.crash(crashOf('a')),
          Cont.crash(crashOf('b'))
        ],
        policy: CrashPolicy.quitFast(),
      ).run((), onCrash: (c) => crash = c);

      expect(
        crash,
        equals(CollectedCrash(
            {0: crashOf('a'), 1: crashOf('b')})),
      );
    });

    test('empty list crashes with an empty CollectedCrash',
        () {
      ContCrash? crash;

      Cont.converge<(), String, int>(
        [],
        policy: CrashPolicy.sequence(),
      ).run((), onCrash: (c) => crash = c);

      expect(crash, equals(const CollectedCrash({})));
    });
  });
}
