import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDo', () {
    test('chains successful values', () {
      int? value;

      Cont.of<(), String, int>(10)
          .thenDo((a) => Cont.of(a * 2))
          .run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('passes through error', () {
      bool chainCalled = false;
      String? error;

      Cont.error<(), String, int>('err').thenDo((a) {
        chainCalled = true;
        return Cont.of(a * 2);
      }).run((), onElse: (e) => error = e);

      expect(chainCalled, false);
      expect(error, 'err');
    });

    test('chains to new error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenDo<int>((a) => Cont.error('chained error'))
          .run((), onElse: (e) => error = e);

      expect(error, 'chained error');
    });

    test('supports type transformation', () {
      String? value;

      Cont.of<(), String, int>(42)
          .thenDo((a) => Cont.of('value: $a'))
          .run((), onThen: (val) => value = val);

      expect(value, 'value: 42');
    });

    test('supports multiple chaining', () {
      int? value;

      Cont.of<(), String, int>(1)
          .thenDo((a) => Cont.of(a + 1))
          .thenDo((a) => Cont.of(a * 10))
          .run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(5).thenDo((a) {
        callCount++;
        return Cont.of(a * 2);
      });

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 10);
      expect(callCount, 2);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42).thenDo<int>((a) {
        throw 'Chain Error';
      }).run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Chain Error');
    });
  });

  group('Cont.thenDo0', () {
    test('chains without value', () {
      String? value;

      Cont.of<(), String, int>(42)
          .thenDo0(() => Cont.of('replaced'))
          .run((), onThen: (val) => value = val);

      expect(value, 'replaced');
    });
  });
}
