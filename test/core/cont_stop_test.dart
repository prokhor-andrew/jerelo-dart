import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.stop', () {
    test(
      'Cont.stop calls onElse with empty errors by default',
      () {
        List<ContError>? errors;
        final cont = Cont.stop<(), int>();

        cont.run((), onElse: (e) => errors = e);
        expect(errors, []);
      },
    );

    test('Cont.stop calls onElse with provided errors', () {
      final error = ContError.capture('test error');
      List<ContError>? errors;
      final cont = Cont.stop<(), int>([error]);

      cont.run((), onElse: (e) => errors = e);
      expect(errors, hasLength(1));
      expect(errors![0].error, 'test error');
    });

    test('Cont.stop with multiple errors', () {
      final error1 = ContError.capture('error 1');
      final error2 = ContError.capture('error 2');
      List<ContError>? errors;
      final cont = Cont.stop<(), int>([error1, error2]);

      cont.run((), onElse: (e) => errors = e);
      expect(errors, hasLength(2));
      expect(errors![0].error, 'error 1');
      expect(errors![1].error, 'error 2');
    });

    test('Cont.stop does not call onThen', () {
      final cont = Cont.stop<(), int>();

      cont.run(
        (),
        onThen: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.stop does not call onPanic', () {
      final cont = Cont.stop<(), int>();

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.stop can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.stop<(), int>();

      cont.run((), onElse: (_) => callCount++);
      cont.run((), onElse: (_) => callCount++);

      expect(callCount, 2);
    });

    test(
      'Cont.stop defensively copies the input error list',
      () {
        final errors = <ContError>[
          ContError.capture('original'),
        ];
        final cont = Cont.stop<(), int>(errors);

        errors.add(
          ContError.capture('added after creation'),
        );

        List<ContError>? received;
        cont.run((), onElse: (e) => received = e);

        expect(received, hasLength(1));
        expect(received![0].error, 'original');
      },
    );

    test(
      'Cont.stop defensively copies errors on each run',
      () {
        final cont = Cont.stop<(), int>([
          ContError.capture('error'),
        ]);

        List<ContError>? firstRun;
        List<ContError>? secondRun;

        cont.run(
          (),
          onElse: (e) {
            firstRun = e;
            e.add(ContError.capture('mutated'));
          },
        );

        cont.run((), onElse: (e) => secondRun = e);

        expect(firstRun, hasLength(2));
        expect(secondRun, hasLength(1));
        expect(secondRun![0].error, 'error');
      },
    );

    test('Cont.stop works with Never value type', () {
      List<ContError>? errors;
      final cont = Cont.stop<(), Never>();

      cont.run(
        (),
        onElse: (e) => errors = e,
        onThen: (_) {
          fail('Should not be called');
        },
      );
      expect(errors, []);
    });

    test(
      'Cont.stop with empty list is same as no argument',
      () {
        List<ContError>? errorsNoArg;
        List<ContError>? errorsEmptyList;

        Cont.stop<(), int>().run(
          (),
          onElse: (e) => errorsNoArg = e,
        );
        Cont.stop<(), int>(
          [],
        ).run((), onElse: (e) => errorsEmptyList = e);

        expect(errorsNoArg, []);
        expect(errorsEmptyList, []);
      },
    );
  });
}
