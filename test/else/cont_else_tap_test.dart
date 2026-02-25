import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTap', () {
    test('promotes to success when side-effect succeeds',
        () {
      String? sideEffectError;
      int? value;

      Cont.error<(), String, int>('err').elseTap((e) {
        sideEffectError = e;
        return Cont.of(99);
      }).run((), onThen: (val) => value = val);

      expect(sideEffectError, 'err');
      expect(value, 99);
    });

    test('passes through value', () {
      bool tapCalled = false;
      int? value;

      Cont.of<(), String, int>(42).elseTap((e) {
        tapCalled = true;
        return Cont.of(99);
      }).run((), onThen: (val) => value = val);

      expect(tapCalled, false);
      expect(value, 42);
    });

    test('keeps original error when side-effect fails', () {
      String? error;

      Cont.error<(), String, int>('original')
          .elseTap<String>((e) => Cont.error('tap error'))
          .run((), onElse: (e) => error = e);

      expect(error, 'original');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.error<(), String, int>('err').elseTap((e) {
        callCount++;
        return Cont.of(99);
      });

      cont.run(());
      expect(callCount, 1);

      cont.run(());
      expect(callCount, 2);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('err').elseTap<int>((e) {
        throw 'Tap Error';
      }).run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Tap Error');
    });
  });

  group('Cont.elseTap0', () {
    test(
        'promotes when side-effect succeeds ignoring error',
        () {
      bool called = false;
      int? value;

      Cont.error<(), String, int>('err').elseTap0(() {
        called = true;
        return Cont.of(99);
      }).run((), onThen: (val) => value = val);

      expect(called, true);
      expect(value, 99);
    });
  });
}
