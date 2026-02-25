import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDo', () {
    test('recovers from error', () {
      int? value;

      Cont.error<(), String, int>('err')
          .elseDo((error) => Cont.of(42))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('receives original error', () {
      String? receivedError;

      Cont.error<(), String, int>('err1')
          .elseDo((error) {
            receivedError = error;
            return Cont.of(0);
          })
          .run(());

      expect(receivedError, 'err1');
    });

    test('propagates only fallback error when both fail', () {
      String? error;

      Cont.error<(), String, int>('original')
          .elseDo((e) {
            return Cont.error<(), String, int>('fallback');
          })
          .run((), onElse: (e) => error = e);

      expect(error, 'fallback');
    });

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), String, int>(42)
          .elseDo((error) {
            elseCalled = true;
            return Cont.of(0);
          })
          .run((), onThen: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('crashes when fallback builder throws', () {
      final cont =
          Cont.error<(), String, int>('err').elseDo((error) {
        throw 'Fallback Builder Error';
      });

      ContCrash? crash;
      cont.run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect(
        (crash! as NormalCrash).error,
        'Fallback Builder Error',
      );
    });

    test('supports type transformation', () {
      int? value;

      Cont.error<(), String, int>('err')
          .elseDo((error) => Cont.of(99))
          .run((), onThen: (val) => value = val);

      expect(value, 99);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.error<(), String, int>('err').elseDo((error) {
        callCount++;
        return Cont.of(callCount);
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

  group('Cont.elseDo0', () {
    test('recovers without error value', () {
      int? value;

      Cont.error<(), String, int>('err')
          .elseDo0(() => Cont.of(42))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });
  });
}
