import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenTap', () {
    test('executes side-effect and returns original value',
        () {
      int? sideEffectValue;
      int? value;

      Cont.of<(), String, int>(42).thenTap((a) {
        sideEffectValue = a;
        return Cont.of('side');
      }).run((), onThen: (val) => value = val);

      expect(sideEffectValue, 42);
      expect(value, 42);
    });

    test('passes through error', () {
      bool tapCalled = false;
      String? error;

      Cont.error<(), String, int>('err').thenTap((a) {
        tapCalled = true;
        return Cont.of('side');
      }).run((), onElse: (e) => error = e);

      expect(tapCalled, false);
      expect(error, 'err');
    });

    test('propagates side-effect error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenTap<String>((a) => Cont.error('tap error'))
          .run((), onElse: (e) => error = e);

      expect(error, 'tap error');
    });

    test('supports chaining with other operations', () {
      final order = <String>[];
      int? value;

      Cont.of<(), String, int>(5).thenTap((a) {
        order.add('tap1: $a');
        return Cont.of('ok');
      }).thenMap((a) {
        order.add('map: $a');
        return a * 2;
      }).thenTap((a) {
        order.add('tap2: $a');
        return Cont.of('ok');
      }).run((), onThen: (val) => value = val);

      expect(order, ['tap1: 5', 'map: 5', 'tap2: 10']);
      expect(value, 10);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(5).thenTap((a) {
        callCount++;
        return Cont.of('ok');
      });

      cont.run(());
      expect(callCount, 1);

      cont.run(());
      expect(callCount, 2);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42).thenTap<int>((a) {
        throw 'Tap Error';
      }).run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Tap Error');
    });
  });

  group('Cont.thenTap0', () {
    test('executes side-effect ignoring value', () {
      bool called = false;
      int? value;

      Cont.of<(), String, int>(42).thenTap0(() {
        called = true;
        return Cont.of('ok');
      }).run((), onThen: (val) => value = val);

      expect(called, true);
      expect(value, 42);
    });
  });
}
