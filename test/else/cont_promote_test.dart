import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.promote', () {
    test('recovers from error with computed value', () {
      int? value;

      Cont.error<(), String, int>('err')
          .promote((e) => 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('receives original error', () {
      String? receivedError;

      Cont.error<(), String, int>('original error')
          .promote((e) {
        receivedError = e;
        return 0;
      }).run(());

      expect(receivedError, 'original error');
    });

    test('passes through value', () {
      bool promoteCalled = false;
      int? value;

      Cont.of<(), String, int>(42).promote((e) {
        promoteCalled = true;
        return 0;
      }).run((), onThen: (val) => value = val);

      expect(promoteCalled, false);
      expect(value, 42);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('err').promote((e) {
        throw 'Promote Error';
      }).run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect(
          (crash! as NormalCrash).error, 'Promote Error');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.error<(), String, int>('err').promote((e) {
        callCount++;
        return callCount;
      });

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

  group('Cont.promote0', () {
    test('recovers ignoring error value', () {
      int? value;

      Cont.error<(), String, int>('err')
          .promote0(() => 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });
  });

  group('Cont.promoteWith', () {
    test('recovers with constant value', () {
      int? value;

      Cont.error<(), String, int>('err')
          .promoteWith(42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });
  });
}
