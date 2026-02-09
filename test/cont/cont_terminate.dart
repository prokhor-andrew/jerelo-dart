
import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.terminate', () {
    test('Cont.terminate calls onTerminate with empty errors by default', () {
      List<ContError>? errors;
      final cont = Cont.terminate<(), int>();

      cont.run((), onTerminate: (e) => errors = e);
      expect(errors, []);
    });

    test('Cont.terminate calls onTerminate with provided errors', () {
      final error = ContError('test error', StackTrace.current);
      List<ContError>? errors;
      final cont = Cont.terminate<(), int>([error]);

      cont.run((), onTerminate: (e) => errors = e);
      expect(errors, hasLength(1));
      expect(errors![0].error, 'test error');
    });

    test('Cont.terminate with multiple errors', () {
      final error1 = ContError('error 1', StackTrace.current);
      final error2 = ContError('error 2', StackTrace.current);
      List<ContError>? errors;
      final cont = Cont.terminate<(), int>([error1, error2]);

      cont.run((), onTerminate: (e) => errors = e);
      expect(errors, hasLength(2));
      expect(errors![0].error, 'error 1');
      expect(errors![1].error, 'error 2');
    });

    test('Cont.terminate does not call onValue', () {
      final cont = Cont.terminate<(), int>();

      cont.run(
        (),
        onValue: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.terminate does not call onPanic', () {
      final cont = Cont.terminate<(), int>();

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.terminate can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.terminate<(), int>();

      cont.run((), onTerminate: (_) => callCount++);
      cont.run((), onTerminate: (_) => callCount++);

      expect(callCount, 2);
    });

    test(
      'Cont.terminate defensively copies the input error list',
      () {
        final errors = <ContError>[
          ContError('original', StackTrace.current),
        ];
        final cont = Cont.terminate<(), int>(errors);

        errors.add(ContError('added after creation', StackTrace.current));

        List<ContError>? received;
        cont.run((), onTerminate: (e) => received = e);

        expect(received, hasLength(1));
        expect(received![0].error, 'original');
      },
    );

    test(
      'Cont.terminate defensively copies errors on each run',
      () {
        final cont = Cont.terminate<(), int>([
          ContError('error', StackTrace.current),
        ]);

        List<ContError>? firstRun;
        List<ContError>? secondRun;

        cont.run((), onTerminate: (e) {
          firstRun = e;
          e.add(ContError('mutated', StackTrace.current));
        });

        cont.run((), onTerminate: (e) => secondRun = e);

        expect(firstRun, hasLength(2));
        expect(secondRun, hasLength(1));
        expect(secondRun![0].error, 'error');
      },
    );

    test('Cont.terminate works with Never value type', () {
      List<ContError>? errors;
      final cont = Cont.terminate<(), Never>();

      cont.run(
        (),
        onTerminate: (e) => errors = e,
        onValue: (_) {
          fail('Should not be called');
        },
      );
      expect(errors, []);
    });

    test('Cont.terminate with empty list is same as no argument', () {
      List<ContError>? errorsNoArg;
      List<ContError>? errorsEmptyList;

      Cont.terminate<(), int>().run(
        (),
        onTerminate: (e) => errorsNoArg = e,
      );
      Cont.terminate<(), int>([]).run(
        (),
        onTerminate: (e) => errorsEmptyList = e,
      );

      expect(errorsNoArg, []);
      expect(errorsEmptyList, []);
    });
  });
}
