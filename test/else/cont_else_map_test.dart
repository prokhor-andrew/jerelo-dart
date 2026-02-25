import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseMap', () {
    test('maps error value', () {
      String? error;

      Cont.error<(), String, int>('err')
          .elseMap((e) => 'mapped: $e')
          .run((), onElse: (e) => error = e);

      expect(error, 'mapped: err');
    });

    test('passes through value', () {
      bool mapCalled = false;
      int? value;

      Cont.of<(), String, int>(42)
          .elseMap((e) {
            mapCalled = true;
            return 'mapped';
          })
          .run((), onThen: (val) => value = val);

      expect(mapCalled, false);
      expect(value, 42);
    });

    test('supports type transformation', () {
      int? error;

      Cont.error<(), String, int>('err')
          .elseMap((e) => e.length)
          .run((), onElse: (e) => error = e);

      expect(error, 3);
    });

    test('supports multiple mapping', () {
      String? error;

      Cont.error<(), String, int>('err')
          .elseMap((e) => e.length)
          .elseMap((e) => 'length: $e')
          .run((), onElse: (e) => error = e);

      expect(error, 'length: 3');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.error<(), String, int>('err').elseMap((e) {
        callCount++;
        return 'mapped: $e ($callCount)';
      });

      String? error1;
      cont.run((), onElse: (e) => error1 = e);
      expect(error1, 'mapped: err (1)');
      expect(callCount, 1);

      String? error2;
      cont.run((), onElse: (e) => error2 = e);
      expect(error2, 'mapped: err (2)');
      expect(callCount, 2);
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('err')
          .elseMap((e) {
            throw 'Map Error';
          })
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Map Error');
    });
  });

  group('Cont.elseMap0', () {
    test('maps without error value', () {
      String? error;

      Cont.error<(), String, int>('err')
          .elseMap0(() => 'replaced')
          .run((), onElse: (e) => error = e);

      expect(error, 'replaced');
    });
  });

  group('Cont.elseMapTo', () {
    test('replaces with constant error', () {
      String? error;

      Cont.error<(), String, int>('err')
          .elseMapTo('constant')
          .run((), onElse: (e) => error = e);

      expect(error, 'constant');
    });
  });
}
