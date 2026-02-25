import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenFork', () {
    test('executes side-effect and returns original value', () {
      bool sideEffectRan = false;
      int? value;

      Cont.of<(), String, int>(42)
          .thenFork((a) {
            sideEffectRan = true;
            return Cont.of('side: $a');
          })
          .run((), onThen: (val) => value = val);

      expect(sideEffectRan, true);
      expect(value, 42);
    });

    test('passes through error', () {
      bool forkCalled = false;
      String? error;

      Cont.error<(), String, int>('err')
          .thenFork<String, String>((a) {
            forkCalled = true;
            return Cont.of('side: $a');
          })
          .run((), onElse: (e) => error = e);

      expect(forkCalled, false);
      expect(error, 'err');
    });

    test('does not propagate side-effect error', () {
      int? value;

      Cont.of<(), String, int>(42)
          .thenFork<String, String>((a) => Cont.error('side error'))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('supports fire-and-forget semantics', () {
      final order = <String>[];

      Cont.of<(), String, int>(5)
          .thenFork((a) {
            order.add('fork: $a');
            return Cont.of('ok');
          })
          .thenMap((a) {
            order.add('map: $a');
            return a * 2;
          })
          .run((), onThen: (_) => order.add('done'));

      expect(order, ['fork: 5', 'map: 5', 'done']);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(5).thenFork((a) {
        callCount++;
        return Cont.of('ok');
      });

      cont.run(());
      expect(callCount, 1);

      cont.run(());
      expect(callCount, 2);
    });
  });

  group('Cont.thenFork0', () {
    test('executes side-effect ignoring value', () {
      bool called = false;
      int? value;

      Cont.of<(), String, int>(42)
          .thenFork0(() {
            called = true;
            return Cont.of('side');
          })
          .run((), onThen: (val) => value = val);

      expect(called, true);
      expect(value, 42);
    });
  });
}
