import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseUnless', () {
    test('recovers to fallback when predicate is false', () {
      int? value;

      Cont.error<(), String, int>('err')
          .elseUnless((e) => false, fallback: 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('keeps error when predicate is true', () {
      String? error;

      Cont.error<(), String, int>('err')
          .elseUnless((e) => true, fallback: 42)
          .run((), onElse: (e) => error = e);

      expect(error, 'err');
    });

    test('passes through value unchanged', () {
      bool predicateCalled = false;
      int? value;

      Cont.of<(), String, int>(42)
          .elseUnless((e) {
            predicateCalled = true;
            return true;
          }, fallback: 0)
          .run((), onThen: (val) => value = val);

      expect(predicateCalled, false);
      expect(value, 42);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.error<(), String, int>('err').elseUnless((e) {
        callCount++;
        return false;
      }, fallback: 42);

      int? value;
      cont.run((), onThen: (val) => value = val);
      expect(value, 42);
      expect(callCount, 1);

      cont.run((), onThen: (val) => value = val);
      expect(callCount, 2);
    });

    test('crashes when predicate throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('err')
          .elseUnless((e) {
            throw 'Predicate Error';
          }, fallback: 42)
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect(
        (crash! as NormalCrash).error,
        'Predicate Error',
      );
    });
  });

  group('Cont.elseUnless0', () {
    test('recovers when zero-arg predicate is false', () {
      int? value;

      Cont.error<(), String, int>('err')
          .elseUnless0(() => false, fallback: 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('keeps error when zero-arg predicate is true', () {
      String? error;

      Cont.error<(), String, int>('err')
          .elseUnless0(() => true, fallback: 42)
          .run((), onElse: (e) => error = e);

      expect(error, 'err');
    });
  });
}
