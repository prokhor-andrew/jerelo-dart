import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenMap', () {
    test('maps successful value', () {
      String? value;

      Cont.of<(), String, int>(42)
          .thenMap((a) => 'mapped: $a')
          .run((), onThen: (val) => value = val);

      expect(value, 'mapped: 42');
    });

    test('passes through error', () {
      bool mapCalled = false;
      String? error;

      Cont.error<(), String, int>('err')
          .thenMap((a) {
            mapCalled = true;
            return a * 2;
          })
          .run((), onElse: (e) => error = e);

      expect(mapCalled, false);
      expect(error, 'err');
    });

    test('supports type transformation', () {
      bool? value;

      Cont.of<(), String, int>(42)
          .thenMap((a) => a > 40)
          .run((), onThen: (val) => value = val);

      expect(value, true);
    });

    test('supports multiple mapping', () {
      String? value;

      Cont.of<(), String, int>(5)
          .thenMap((a) => a * 2)
          .thenMap((a) => 'result: $a')
          .run((), onThen: (val) => value = val);

      expect(value, 'result: 10');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(5).thenMap((a) {
        callCount++;
        return a * 2;
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

      Cont.of<(), String, int>(42)
          .thenMap((a) {
            throw 'Map Error';
          })
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Map Error');
    });
  });

  group('Cont.thenMap0', () {
    test('maps without value', () {
      String? value;

      Cont.of<(), String, int>(42)
          .thenMap0(() => 'replaced')
          .run((), onThen: (val) => value = val);

      expect(value, 'replaced');
    });
  });

  group('Cont.thenMapTo', () {
    test('replaces with constant value', () {
      String? value;

      Cont.of<(), String, int>(42)
          .thenMapTo('constant')
          .run((), onThen: (val) => value = val);

      expect(value, 'constant');
    });
  });

  group('Cont.thenMapWithEnv', () {
    test('maps with environment and value', () {
      String? value;

      Cont.of<String, String, int>(10)
          .thenMapWithEnv((env, a) => '$env: $a')
          .run('hello', onThen: (val) => value = val);

      expect(value, 'hello: 10');
    });
  });
}
