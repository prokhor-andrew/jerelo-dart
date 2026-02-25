import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenZip', () {
    test('combines values from both continuations', () {
      String? value;

      Cont.of<(), String, int>(10)
          .thenZip(
            (a) => Cont.of(a * 2),
            (a, b) => '$a + $b',
          )
          .run((), onThen: (val) => value = val);

      expect(value, '10 + 20');
    });

    test('passes through error', () {
      bool zipCalled = false;
      String? error;

      Cont.error<(), String, int>('err')
          .thenZip<int, String>(
            (a) {
              zipCalled = true;
              return Cont.of(a * 2);
            },
            (a, b) => '$a + $b',
          )
          .run((), onElse: (e) => error = e);

      expect(zipCalled, false);
      expect(error, 'err');
    });

    test('propagates error from zipped continuation', () {
      String? error;

      Cont.of<(), String, int>(10)
          .thenZip<int, String>(
            (a) => Cont.error('zip error'),
            (a, b) => '$a + $b',
          )
          .run((), onElse: (e) => error = e);

      expect(error, 'zip error');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(5).thenZip(
        (a) {
          callCount++;
          return Cont.of(a * 2);
        },
        (a, b) => a + b,
      );

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 15);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 15);
      expect(callCount, 2);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42)
          .thenZip<int, String>(
            (a) {
              throw 'Zip Error';
            },
            (a, b) => '$a + $b',
          )
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Zip Error');
    });
  });

  group('Cont.thenZip0', () {
    test('combines values ignoring source value in factory', () {
      String? value;

      Cont.of<(), String, int>(10)
          .thenZip0(
            () => Cont.of(99),
            (a, b) => '$a + $b',
          )
          .run((), onThen: (val) => value = val);

      expect(value, '10 + 99');
    });
  });
}
