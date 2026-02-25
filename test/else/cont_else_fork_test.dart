import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseFork', () {
    test('executes side-effect and returns original error', () {
      bool sideEffectRan = false;
      String? error;

      Cont.error<(), String, int>('err')
          .elseFork((e) {
            sideEffectRan = true;
            return Cont.of('side: $e');
          })
          .run((), onElse: (e) => error = e);

      expect(sideEffectRan, true);
      expect(error, 'err');
    });

    test('passes through value', () {
      bool forkCalled = false;
      int? value;

      Cont.of<(), String, int>(42)
          .elseFork<String, String>((e) {
            forkCalled = true;
            return Cont.of('side');
          })
          .run((), onThen: (val) => value = val);

      expect(forkCalled, false);
      expect(value, 42);
    });

    test('does not propagate side-effect error', () {
      String? error;

      Cont.error<(), String, int>('original')
          .elseFork<String, String>(
            (e) => Cont.error('side error'),
          )
          .run((), onElse: (e) => error = e);

      expect(error, 'original');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.error<(), String, int>('err').elseFork((e) {
        callCount++;
        return Cont.of('ok');
      });

      cont.run(());
      expect(callCount, 1);

      cont.run(());
      expect(callCount, 2);
    });
  });

  group('Cont.elseFork0', () {
    test('executes side-effect ignoring error', () {
      bool called = false;
      String? error;

      Cont.error<(), String, int>('err')
          .elseFork0(() {
            called = true;
            return Cont.of('side');
          })
          .run((), onElse: (e) => error = e);

      expect(called, true);
      expect(error, 'err');
    });
  });
}
