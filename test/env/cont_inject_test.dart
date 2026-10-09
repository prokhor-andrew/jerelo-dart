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
          .run((), onThen: (val) => value = val);

      expect(value, 'env: 42');
    });

    test('passes through source termination', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('source err')])
          .injectInto(Cont.of<int, String>('result'))
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'source err');
    });

    test('passes through target termination', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .injectInto(
            Cont.stop<int, String>([
              ContError.capture('target err'),
            ]),
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'target err');
    });

    test('never executes target on source failure', () {
      bool targetCalled = false;

      Cont.stop<(), int>()
          .injectInto(
            Cont.fromRun<int, String>((runtime, observer) {
              targetCalled = true;
              observer.onThen('result');
            }),
          )
          .run((), onElse: (_) {});

      expect(targetCalled, false);
    });

    test('supports type transformation', () {
      String? value;

      // Source produces int, target uses int as env to produce String
      Cont.of<(), int>(5)
          .injectInto(
            Cont.ask<int>().thenMap((n) => 'number is $n'),
          )
          .run((), onThen: (val) => value = val);

      expect(value, 'number is 5');
    });

    test('supports multiple runs', () {
      var callCount = 0;

      final cont = Cont.of<(), int>(42).injectInto(
        Cont.fromRun<int, String>((runtime, observer) {
          callCount++;
          observer.onThen('result ${runtime.env()}');
        }),
      );

      String? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 'result 42');
      expect(callCount, 1);

      String? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 'result 42');
      expect(callCount, 2);
    });

    test('supports Cont<E, Never> target', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .injectInto(
            Cont.fromRun<int, Never>((runtime, observer) {
              observer.onElse([
                ContError.capture('never error'),
              ]);
            }),
          )
          .run((), onElse: (e) => errors = e);

      expect(errors![0].error, 'never error');
    });
  });

  group('Cont.injectedBy', () {
    test('receives environment from provider', () {
      String? value;

      Cont.ask<int>()
          .thenMap((env) => 'env: $env')
          .injectedBy(Cont.of<(), int>(42))
          .run((), onThen: (val) => value = val);

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
          .run((), onThen: (val) => value1 = val);
      target
          .injectedBy(provider)
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('passes through provider termination', () {
      List<ContError>? errors;

      Cont.of<int, String>('result')
          .injectedBy(
            Cont.stop<(), int>([
              ContError.capture('provider err'),
            ]),
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'provider err');
    });

    test('passes through own termination', () {
      List<ContError>? errors;

      Cont.stop<int, String>([ContError.capture('own err')])
          .injectedBy(Cont.of<(), int>(42))
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'own err');
    });
  });
}
