import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromRun throws', () {
    test('a throw before reporting is a crash', () {
      ContCrash? crash;
      NormalCrash? panic;

      Cont.fromRun<(), String, int>((env, observer) {
        throw 'BEFORE';
      }).run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (p) => panic = p,
      );

      expect(
          (crash! as NormalCrash).error, equals('BEFORE'));
      expect(panic, isNull);
    });

    test(
        'a throw after onThen is a panic, and the value stands',
        () {
      final values = <int>[];
      final panics = <NormalCrash>[];
      ContCrash? crash;

      Cont.fromRun<(), String, int>((env, observer) {
        observer.onThen(1);
        throw 'AFTER';
      }).run(
        (),
        onThen: values.add,
        onCrash: (c) => crash = c,
        onPanic: panics.add,
      );

      expect(values, equals([1]));
      expect(crash, isNull);
      expect(panics.map((p) => p.error), equals(['AFTER']));
    });

    test(
        'a throw after onElse is a panic, and the error stands',
        () {
      final errors = <String>[];
      final panics = <NormalCrash>[];
      ContCrash? crash;

      Cont.fromRun<(), String, int>((env, observer) {
        observer.onElse('E');
        throw 'AFTER';
      }).run(
        (),
        onElse: errors.add,
        onCrash: (c) => crash = c,
        onPanic: panics.add,
      );

      expect(errors, equals(['E']));
      expect(crash, isNull);
      expect(panics.map((p) => p.error), equals(['AFTER']));
    });

    test(
        'a throw after onCrash is a panic, and the crash stands',
        () {
      final crashes = <ContCrash>[];
      final panics = <NormalCrash>[];
      final first = switch (ContCrash.tryCatch<void>(() {
        throw 'FIRST';
      })) {
        CrashCrashOr(crash: final crash) => crash,
        ValueCrashOr() =>
          throw StateError('expected a crash'),
      };

      Cont.fromRun<(), String, int>((env, observer) {
        observer.onCrash(first);
        throw 'AFTER';
      }).run(
        (),
        onCrash: crashes.add,
        onPanic: panics.add,
      );

      expect(crashes, equals([first]));
      expect(panics.map((p) => p.error), equals(['AFTER']));
    });

    test(
        'a throw after reporting inside a chain is a panic',
        () {
      final values = <int>[];
      final panics = <NormalCrash>[];
      ContCrash? crash;

      Cont.fromRun<(), String, int>((env, observer) {
        observer.onThen(1);
        throw 'AFTER';
      }).thenMap((x) => x + 1).run(
        (),
        onThen: values.add,
        onCrash: (c) => crash = c,
        onPanic: panics.add,
      );

      expect(values, equals([2]));
      expect(crash, isNull);
      expect(panics.map((p) => p.error), equals(['AFTER']));
    });
  });
}
