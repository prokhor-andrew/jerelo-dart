import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.injectInto', () {
    test('injects value as environment', () {
      String? value;

      Cont.of<(), int>(42)
          .injectInto(
            Cont.ask<int>().thenMap((env) => 'env: $env'),
          )
          .run((), onValue: (val) => value = val);

      expect(value, 'env: 42');
    });

    test('passes through source termination', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError.capture('source err'),
          ])
          .injectInto(Cont.of<int, String>('result'))
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'source err');
    });

    test('passes through target termination', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .injectInto(
            Cont.terminate<int, String>([
              ContError.capture('target err'),
            ]),
          )
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'target err');
    });

    test('never executes target on source failure', () {
      bool targetCalled = false;

      Cont.terminate<(), int>()
          .injectInto(
            Cont.fromRun<int, String>((runtime, observer) {
              targetCalled = true;
              observer.onValue('result');
            }),
          )
          .run((), onTerminate: (_) {});

      expect(targetCalled, false);
    });

    test('supports type transformation', () {
      String? value;

      // Source produces int, target uses int as env to produce String
      Cont.of<(), int>(5)
          .injectInto(
            Cont.ask<int>().thenMap((n) => 'number is $n'),
          )
          .run((), onValue: (val) => value = val);

      expect(value, 'number is 5');
    });

    test('supports multiple runs', () {
      var callCount = 0;

      final cont = Cont.of<(), int>(42).injectInto(
        Cont.fromRun<int, String>((runtime, observer) {
          callCount++;
          observer.onValue('result ${runtime.env()}');
        }),
      );

      String? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 'result 42');
      expect(callCount, 1);

      String? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 'result 42');
      expect(callCount, 2);
    });

    test('supports Cont<E, Never> target', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .injectInto(
            Cont.fromRun<int, Never>((runtime, observer) {
              observer.onTerminate([
                ContError.capture('never error'),
              ]);
            }),
          )
          .run((), onTerminate: (e) => errors = e);

      expect(errors![0].error, 'never error');
    });
  });

  group('Cont.injectedBy', () {
    test('receives environment from provider', () {
      String? value;

      Cont.ask<int>()
          .thenMap((env) => 'env: $env')
          .injectedBy(Cont.of<(), int>(42))
          .run((), onValue: (val) => value = val);

      expect(value, 'env: 42');
    });

    test('is equivalent to provider.injectInto(this)', () {
      String? value1;
      String? value2;

      final target = Cont.ask<int>().thenMap(
        (env) => 'env: $env',
      );
      final provider = Cont.of<(), int>(42);

      provider
          .injectInto(target)
          .run((), onValue: (val) => value1 = val);
      target
          .injectedBy(provider)
          .run((), onValue: (val) => value2 = val);

      expect(value1, value2);
    });

    test('passes through provider termination', () {
      List<ContError>? errors;

      Cont.of<int, String>('result')
          .injectedBy(
            Cont.terminate<(), int>([
              ContError.capture('provider err'),
            ]),
          )
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'provider err');
    });

    test('passes through own termination', () {
      List<ContError>? errors;

      Cont.terminate<int, String>([
            ContError.capture('own err'),
          ])
          .injectedBy(Cont.of<(), int>(42))
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'own err');
    });
  });
}
