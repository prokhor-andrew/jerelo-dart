import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('loops', () {
    test('thenWhile supports asynchronous iterations',
        () async {
      final completer = Completer<int>();
      var n = 0;

      Cont.fromRun<(), String, int>((env, observer) {
        Timer(Duration.zero, () => observer.onThen(++n));
        return () {};
      }).thenWhile((v) => v < 3).run(
        (),
        onThen: completer.complete,
      );

      expect(await completer.future, equals(3));
    });

    test('a crash ends thenWhile', () {
      ContCrash? crash;

      Cont.fromRun<(), String, int>((env, observer) {
        throw 'boom';
      }).thenWhile((_) => true).run(
        (),
        onCrash: (c) => crash = c,
      );

      expect((crash! as NormalCrash).error, equals('boom'));
    });

    test('a throwing predicate crashes thenWhile', () {
      ContCrash? crash;

      Cont.of<(), String, int>(1)
          .thenWhile((_) => throw 'predicate')
          .run((), onCrash: (c) => crash = c);

      expect((crash! as NormalCrash).error,
          equals('predicate'));
    });

    test('a throwing predicate crashes elseWhile', () {
      ContCrash? crash;

      Cont.error<(), String, int>('E')
          .elseWhile((_) => throw 'predicate')
          .run((), onCrash: (c) => crash = c);

      expect((crash! as NormalCrash).error,
          equals('predicate'));
    });

    test('crashWhile retries while the predicate holds',
        () {
      var attempts = 0;
      ContCrash? crash;

      Cont.fromRun<(), String, int>((env, observer) {
        attempts++;
        throw 'attempt $attempts';
      }).crashWhile((_) => attempts < 3).run(
        (),
        onCrash: (c) => crash = c,
      );

      expect(attempts, equals(3));
      expect((crash! as NormalCrash).error,
          equals('attempt 3'));
    });

    test('a throwing predicate crashes crashWhile', () {
      ContCrash? crash;

      Cont.fromRun<(), String, int>((env, observer) {
        throw 'boom';
      }).crashWhile((_) => throw 'predicate').run(
        (),
        onCrash: (c) => crash = c,
      );

      expect((crash! as NormalCrash).error,
          equals('predicate'));
    });

    test('thenWhileWithEnv reads the environment', () {
      int? result;
      var n = 0;

      Cont.fromRun<int, String, int>((env, observer) {
        observer.onThen(++n);
        return () {};
      })
          .thenWhileWithEnv((limit, v) => v < limit)
          .run(7, onThen: (v) => result = v);

      expect(result, equals(7));
    });
  });
}
