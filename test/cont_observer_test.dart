import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('ContObserver', () {
    group('constructor', () {
      test('creates observer with terminate and value handlers', () {
        var terminateCalled = false;
        var valueCalled = false;

        final observer = ContObserver<int>(
          (errors) => terminateCalled = true,
          (value) => valueCalled = true,
        );

        observer.onTerminate([]);
        expect(terminateCalled, isTrue);
        expect(valueCalled, isFalse);

        observer.onValue(42);
        expect(valueCalled, isTrue);
      });

      test('onValue receives correct value', () {
        int? receivedValue;

        final observer = ContObserver<int>(
          (errors) {},
          (value) => receivedValue = value,
        );

        observer.onValue(123);

        expect(receivedValue, equals(123));
      });

      test('onTerminate receives correct errors', () {
        List<ContError>? receivedErrors;

        final observer = ContObserver<int>(
          (errors) => receivedErrors = errors,
          (value) {},
        );

        final error = ContError('test error', StackTrace.current);
        observer.onTerminate([error]);

        expect(receivedErrors, isNotNull);
        expect(receivedErrors!.length, equals(1));
        expect(receivedErrors![0].error, equals('test error'));
      });

      test('onTerminate with default empty list', () {
        List<ContError>? receivedErrors;

        final observer = ContObserver<int>(
          (errors) => receivedErrors = errors,
          (value) {},
        );

        observer.onTerminate();

        expect(receivedErrors, isNotNull);
        expect(receivedErrors, isEmpty);
      });

      test('handles generic types correctly', () {
        String? receivedValue;

        final observer = ContObserver<String>(
          (errors) {},
          (value) => receivedValue = value,
        );

        observer.onValue('hello');

        expect(receivedValue, equals('hello'));
      });

      test('handles nullable types', () {
        int? receivedValue;
        var wasCalled = false;

        final observer = ContObserver<int?>(
          (errors) {},
          (value) {
            wasCalled = true;
            receivedValue = value;
          },
        );

        observer.onValue(null);

        expect(wasCalled, isTrue);
        expect(receivedValue, isNull);
      });
    });

    group('ignore', () {
      test('creates observer that ignores terminate', () {
        final observer = ContObserver.ignore<int>();

        expect(() => observer.onTerminate([]), returnsNormally);
      });

      test('creates observer that ignores value', () {
        final observer = ContObserver.ignore<int>();

        expect(() => observer.onValue(42), returnsNormally);
      });

      test('creates observer that ignores terminate with errors', () {
        final observer = ContObserver.ignore<String>();

        final errors = [
          ContError('error1', StackTrace.current),
          ContError('error2', StackTrace.current),
        ];

        expect(() => observer.onTerminate(errors), returnsNormally);
      });

      test('works with different generic types', () {
        final intObserver = ContObserver.ignore<int>();
        final stringObserver = ContObserver.ignore<String>();
        final listObserver = ContObserver.ignore<List<int>>();

        expect(() => intObserver.onValue(42), returnsNormally);
        expect(() => stringObserver.onValue('test'), returnsNormally);
        expect(() => listObserver.onValue([1, 2, 3]), returnsNormally);
      });
    });

    group('copyUpdateOnTerminate', () {
      test('creates new observer with updated terminate handler', () {
        var originalTerminateCalled = false;
        var newTerminateCalled = false;
        var originalValueCalled = false;

        final original = ContObserver<int>(
          (errors) => originalTerminateCalled = true,
          (value) => originalValueCalled = true,
        );

        final updated = original.copyUpdateOnTerminate(
          (errors) => newTerminateCalled = true,
        );

        updated.onTerminate([]);

        expect(originalTerminateCalled, isFalse);
        expect(newTerminateCalled, isTrue);
      });

      test('preserves original value handler', () {
        int? receivedValue;

        final original = ContObserver<int>(
          (errors) {},
          (value) => receivedValue = value,
        );

        final updated = original.copyUpdateOnTerminate((errors) {});

        updated.onValue(42);

        expect(receivedValue, equals(42));
      });

      test('passes errors to new handler', () {
        List<ContError>? receivedErrors;

        final original = ContObserver<int>(
          (errors) {},
          (value) {},
        );

        final updated = original.copyUpdateOnTerminate(
          (errors) => receivedErrors = errors,
        );

        final error = ContError('test', StackTrace.current);
        updated.onTerminate([error]);

        expect(receivedErrors, isNotNull);
        expect(receivedErrors!.length, equals(1));
      });

      test('does not affect original observer', () {
        var originalCalled = false;

        final original = ContObserver<int>(
          (errors) => originalCalled = true,
          (value) {},
        );

        final updated = original.copyUpdateOnTerminate((errors) {});

        original.onTerminate([]);

        expect(originalCalled, isTrue);
      });

      test('can be chained multiple times', () {
        var handler1Called = false;
        var handler2Called = false;

        final original = ContObserver<int>(
          (errors) {},
          (value) {},
        );

        final updated1 = original.copyUpdateOnTerminate(
          (errors) => handler1Called = true,
        );

        final updated2 = updated1.copyUpdateOnTerminate(
          (errors) => handler2Called = true,
        );

        updated2.onTerminate([]);

        expect(handler1Called, isFalse);
        expect(handler2Called, isTrue);
      });
    });

    group('copyUpdateOnValue', () {
      test('creates new observer with updated value handler', () {
        var originalValueCalled = false;
        var newValueCalled = false;

        final original = ContObserver<int>(
          (errors) {},
          (value) => originalValueCalled = true,
        );

        final updated = original.copyUpdateOnValue<String>(
          (value) => newValueCalled = true,
        );

        updated.onValue('test');

        expect(originalValueCalled, isFalse);
        expect(newValueCalled, isTrue);
      });

      test('preserves original terminate handler', () {
        var terminateCalled = false;

        final original = ContObserver<int>(
          (errors) => terminateCalled = true,
          (value) {},
        );

        final updated = original.copyUpdateOnValue<String>((value) {});

        updated.onTerminate([]);

        expect(terminateCalled, isTrue);
      });

      test('passes value to new handler', () {
        String? receivedValue;

        final original = ContObserver<int>(
          (errors) {},
          (value) {},
        );

        final updated = original.copyUpdateOnValue<String>(
          (value) => receivedValue = value,
        );

        updated.onValue('hello');

        expect(receivedValue, equals('hello'));
      });

      test('can change type from int to String', () {
        String? receivedValue;

        final original = ContObserver<int>(
          (errors) {},
          (value) {},
        );

        final updated = original.copyUpdateOnValue<String>(
          (value) => receivedValue = value,
        );

        updated.onValue('converted');

        expect(receivedValue, equals('converted'));
      });

      test('can change type from simple to complex', () {
        List<int>? receivedValue;

        final original = ContObserver<int>(
          (errors) {},
          (value) {},
        );

        final updated = original.copyUpdateOnValue<List<int>>(
          (value) => receivedValue = value,
        );

        updated.onValue([1, 2, 3]);

        expect(receivedValue, equals([1, 2, 3]));
      });

      test('does not affect original observer', () {
        int? originalValue;

        final original = ContObserver<int>(
          (errors) {},
          (value) => originalValue = value,
        );

        original.copyUpdateOnValue<String>((value) {});

        original.onValue(42);

        expect(originalValue, equals(42));
      });

      test('can be chained with type changes', () {
        String? finalValue;

        final original = ContObserver<int>(
          (errors) {},
          (value) {},
        );

        final updated1 = original.copyUpdateOnValue<double>(
          (value) {},
        );

        final updated2 = updated1.copyUpdateOnValue<String>(
          (value) => finalValue = value,
        );

        updated2.onValue('final');

        expect(finalValue, equals('final'));
      });
    });

    group('edge cases', () {
      test('handlers can be called multiple times', () {
        var valueCount = 0;
        var terminateCount = 0;

        final observer = ContObserver<int>(
          (errors) => terminateCount++,
          (value) => valueCount++,
        );

        observer.onValue(1);
        observer.onValue(2);
        observer.onValue(3);

        expect(valueCount, equals(3));

        observer.onTerminate([]);
        observer.onTerminate([]);

        expect(terminateCount, equals(2));
      });

      test('handlers can throw exceptions', () {
        final observer = ContObserver<int>(
          (errors) => throw Exception('terminate error'),
          (value) => throw Exception('value error'),
        );

        expect(() => observer.onValue(42), throwsException);
        expect(() => observer.onTerminate([]), throwsException);
      });

      test('handlers can have side effects', () {
        final values = <int>[];
        final errors = <List<ContError>>[];

        final observer = ContObserver<int>(
          (e) => errors.add(e),
          (v) => values.add(v),
        );

        observer.onValue(1);
        observer.onValue(2);
        observer.onTerminate([ContError('e1', StackTrace.current)]);
        observer.onValue(3);
        observer.onTerminate([ContError('e2', StackTrace.current)]);

        expect(values, equals([1, 2, 3]));
        expect(errors.length, equals(2));
      });

      test('observer with void value type', () {
        var valueCalled = false;

        final observer = ContObserver<void>(
          (errors) {},
          (value) => valueCalled = true,
        );

        observer.onValue(null);

        expect(valueCalled, isTrue);
      });

      test('observer with function type', () {
        int Function(int)? receivedFunction;

        final observer = ContObserver<int Function(int)>(
          (errors) {},
          (value) => receivedFunction = value,
        );

        observer.onValue((x) => x * 2);

        expect(receivedFunction, isNotNull);
        expect(receivedFunction!(5), equals(10));
      });

      test('onTerminate with multiple errors', () {
        List<ContError>? received;

        final observer = ContObserver<int>(
          (errors) => received = errors,
          (value) {},
        );

        final errors = [
          ContError('error1', StackTrace.current),
          ContError('error2', StackTrace.current),
          ContError('error3', StackTrace.current),
        ];

        observer.onTerminate(errors);

        expect(received, isNotNull);
        expect(received!.length, equals(3));
        expect(received![0].error, equals('error1'));
        expect(received![1].error, equals('error2'));
        expect(received![2].error, equals('error3'));
      });
    });
  });
}
