import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseZip', () {
    test('combines errors from both continuations', () {
      String? error;

      Cont.error<(), String, int>('err1')
          .elseZip(
            (e) => Cont.error<(), String, int>('err2'),
            (a, b) => '$a + $b',
          )
          .run((), onElse: (e) => error = e);

      expect(error, 'err1 + err2');
    });

    test('passes through value', () {
      bool zipCalled = false;
      int? value;

      Cont.of<(), String, int>(42)
          .elseZip<String, String>(
            (e) {
              zipCalled = true;
              return Cont.error('err2');
            },
            (a, b) => '$a + $b',
          )
          .run((), onThen: (val) => value = val);

      expect(zipCalled, false);
      expect(value, 42);
    });

    test('recovers when zipped continuation succeeds', () {
      int? value;

      Cont.error<(), String, int>('err1')
          .elseZip<String, String>(
            (e) => Cont.of(42),
            (a, b) => '$a + $b',
          )
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.error<(), String, int>('err1').elseZip(
        (e) {
          callCount++;
          return Cont.error<(), String, int>('err2');
        },
        (a, b) => '$a + $b',
      );

      String? error1;
      cont.run((), onElse: (e) => error1 = e);
      expect(error1, 'err1 + err2');
      expect(callCount, 1);

      String? error2;
      cont.run((), onElse: (e) => error2 = e);
      expect(error2, 'err1 + err2');
      expect(callCount, 2);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('err')
          .elseZip<String, String>(
            (e) {
              throw 'Zip Error';
            },
            (a, b) => '$a + $b',
          )
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Zip Error');
    });
  });

  group('Cont.elseZip0', () {
    test('combines errors ignoring source error in factory', () {
      String? error;

      Cont.error<(), String, int>('err1')
          .elseZip0(
            () => Cont.error<(), String, int>('err2'),
            (a, b) => '$a + $b',
          )
          .run((), onElse: (e) => error = e);

      expect(error, 'err1 + err2');
    });
  });
}
