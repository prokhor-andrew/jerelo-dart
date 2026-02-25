import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenIf', () {
    test('passes through when predicate is true', () {
      int? value;

      Cont.of<(), String, int>(42)
          .thenIf((a) => a > 40, fallback: 'too small')
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('terminates with fallback when predicate is false', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenIf((a) => a > 100, fallback: 'too small')
          .run((), onElse: (e) => error = e);

      expect(error, 'too small');
    });

    test('passes through error unchanged', () {
      bool predicateCalled = false;
      String? error;

      Cont.error<(), String, int>('original')
          .thenIf((a) {
            predicateCalled = true;
            return a > 0;
          }, fallback: 'fallback')
          .run((), onElse: (e) => error = e);

      expect(predicateCalled, false);
      expect(error, 'original');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(42).thenIf((a) {
        callCount++;
        return a > 40;
      }, fallback: 'too small');

      int? value;
      cont.run((), onThen: (val) => value = val);
      expect(value, 42);
      expect(callCount, 1);

      cont.run((), onThen: (val) => value = val);
      expect(callCount, 2);
    });

    test('crashes when predicate throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42)
          .thenIf((a) {
            throw 'Predicate Error';
          }, fallback: 'fallback')
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Predicate Error');
    });
  });

  group('Cont.thenIf0', () {
    test('passes through when predicate is true', () {
      int? value;

      Cont.of<(), String, int>(42)
          .thenIf0(() => true, fallback: 'err')
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('terminates with fallback when predicate is false', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenIf0(() => false, fallback: 'err')
          .run((), onElse: (e) => error = e);

      expect(error, 'err');
    });
  });
}
