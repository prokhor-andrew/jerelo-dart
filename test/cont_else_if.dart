import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseIf', () {
    test('recovers when predicate is true', () {
      int? value;

      Cont.stop<(), int>([ContError.capture('error')])
          .elseIf(
            (errors) => errors.first.error == 'error',
            42,
          )
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test(
      'continues terminating when predicate is false',
      () {
        List<ContError>? errors;
        int? value;

        Cont.stop<(), int>([ContError.capture('fatal')])
            .elseIf(
              (errors) => errors.first.error == 'not found',
              42,
            )
            .run(
              (),
              onThen: (val) => value = val,
              onElse: (e) => errors = e,
            );

        expect(value, null);
        expect(errors, isNotNull);
        expect(errors!.length, 1);
        expect(errors![0].error, 'fatal');
      },
    );

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseIf((errors) {
            elseCalled = true;
            return true;
          }, 0)
          .run((), onThen: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('receives original errors', () {
      List<ContError>? receivedErrors;

      Cont.stop<(), int>([
            ContError.capture('err1'),
            ContError.capture('err2'),
          ])
          .elseIf((errors) {
            receivedErrors = errors;
            return false; // don't recover, just capture errors
          }, 0)
          .run((), onElse: (_) {});

      expect(receivedErrors!.length, 2);
      expect(receivedErrors![0].error, 'err1');
      expect(receivedErrors![1].error, 'err2');
    });

    test('works with multiple errors', () {
      int? value;

      Cont.stop<(), int>([
            ContError.capture('err1'),
            ContError.capture('err2'),
            ContError.capture('err3'),
          ])
          .elseIf((errors) => errors.length == 3, 99)
          .run((), onThen: (val) => value = val);

      expect(value, 99);
    });

    test('terminates when predicate throws', () {
      final cont =
          Cont.stop<(), int>([
            ContError.capture('error'),
          ]).elseIf((errors) {
            throw 'Predicate Error';
          }, 42);

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Predicate Error');
    });

    test(
      'passes through when none of the predicates match',
      () {
        List<ContError>? errors;

        Cont.stop<(), int>([ContError.capture('unknown')])
            .elseIf(
              (errors) => errors.first.error == 'not found',
              1,
            )
            .elseIf(
              (errors) => errors.first.error == 'timeout',
              2,
            )
            .run((), onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'unknown');
      },
    );

    test('works with empty error list', () {
      int? value;

      Cont.stop<(), int>([])
          .elseIf((errors) => errors.isEmpty, 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont =
          Cont.stop<(), int>([
            ContError.capture('error'),
          ]).elseIf((errors) {
            callCount++;
            return true;
          }, 10);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 10);
      expect(callCount, 2);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseIf((errors) => true, 0)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
          );
    });

    test('provides defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<(), int>(originalErrors)
          .elseIf((errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return false;
          }, 0)
          .run((), onElse: (_) {});

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('prevents recovery after cancellation', () {
      bool predicateCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            buffer.add(() {
              if (runtime.isCancelled()) return;
              observer.onElse([ContError.capture('error')]);
            });
          }).elseIf((errors) {
            predicateCalled = true;
            return true;
          }, 42);

      int? value;
      final token = cont.run(
        (),
        onThen: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(predicateCalled, false);
      expect(value, null);
    });
  });
}
