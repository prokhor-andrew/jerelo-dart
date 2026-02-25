import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenInject', () {
    test('injects value as environment', () {
      String? value;

      Cont.of<(), String, int>(42)
          .thenInject(
        Cont.askThen<int, String>()
            .thenMap((env) => 'env: $env'),
      )
          .run((), onThen: (val) => value = val);

      expect(value, 'env: 42');
    });

    test('passes through source error', () {
      String? error;

      Cont.error<(), String, int>('source err')
          .thenInject(
              Cont.of<int, String, String>('result'))
          .run((), onElse: (e) => error = e);

      expect(error, 'source err');
    });

    test('passes through target error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenInject(
        Cont.error<int, String, String>('target err'),
      )
          .run((), onElse: (e) => error = e);

      expect(error, 'target err');
    });

    test('never executes target on source failure', () {
      bool targetCalled = false;

      Cont.error<(), String, int>('err').thenInject(
        Cont.fromRun<int, String, String>(
            (runtime, observer) {
          targetCalled = true;
          observer.onThen('result');
        }),
      ).run((), onElse: (_) {});

      expect(targetCalled, false);
    });

    test('supports type transformation', () {
      String? value;

      Cont.of<(), String, int>(5)
          .thenInject(
        Cont.askThen<int, String>()
            .thenMap((n) => 'number is $n'),
      )
          .run((), onThen: (val) => value = val);

      expect(value, 'number is 5');
    });

    test('supports multiple runs', () {
      var callCount = 0;

      final cont = Cont.of<(), String, int>(10).thenInject(
        Cont.fromRun<int, String, String>(
            (runtime, observer) {
          callCount++;
          observer.onThen('env: ${runtime.env()}');
        }),
      );

      String? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 'env: 10');
      expect(callCount, 1);

      String? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 'env: 10');
      expect(callCount, 2);
    });
  });
}
