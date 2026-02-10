import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('ContError', () {
    test('stores error and stackTrace correctly', () {
      final error = Exception('test error');
      final stackTrace = StackTrace.current;

      final contError = ContError(error, stackTrace);

      expect(contError.error, equals(error));
      expect(contError.stackTrace, equals(stackTrace));
    });

    test('supports empty StackTrace', () {
      final error = Exception('test');

      final contError = ContError(error, StackTrace.empty);

      expect(
        contError.stackTrace,
        equals(StackTrace.empty),
      );
    });

    test('supports const context', () {
      const contError = ContError(
        'const error',
        StackTrace.empty,
      );

      expect(contError.error, equals('const error'));
      expect(
        contError.stackTrace,
        equals(StackTrace.empty),
      );
    });

    test('toString method provides readable format', () {
      final error = Exception('test error');
      final stackTrace = StackTrace.current;
      final contError = ContError(error, stackTrace);

      final str = contError.toString();

      // ContError uses default object toString which includes the type
      expect(str, isNotEmpty);
      expect(
        contError.error.toString(),
        contains('test error'),
      );
    });

    test('error with Exception type', () {
      final error = Exception('exception message');
      final contError = ContError(error, StackTrace.empty);

      expect(contError.error, isA<Exception>());
      expect(
        contError.error.toString(),
        contains('exception message'),
      );
    });

    test('error with Error type', () {
      final error = ArgumentError('invalid argument');
      final contError = ContError(error, StackTrace.empty);

      expect(contError.error, isA<ArgumentError>());
      expect(
        contError.error.toString(),
        contains('invalid argument'),
      );
    });

    test('error with String type', () {
      const error = 'plain string error';
      const contError = ContError(error, StackTrace.empty);

      expect(contError.error, isA<String>());
      expect(contError.error, equals('plain string error'));
    });

    test('error with custom type', () {
      final error = CustomError('custom', 42);
      final contError = ContError(error, StackTrace.empty);

      expect(contError.error, isA<CustomError>());
      expect(
        (contError.error as CustomError).message,
        'custom',
      );
      expect((contError.error as CustomError).code, 42);
    });

    test('stack trace formatting is preserved', () {
      final stackTrace = StackTrace.current;
      final contError = ContError('error', stackTrace);

      expect(contError.stackTrace, same(stackTrace));
      expect(contError.stackTrace.toString(), isNotEmpty);
    });

    test('preserves stack trace across operations', () {
      final originalStack = StackTrace.current;
      final contError = ContError('test', originalStack);

      // Stack trace should be the exact same object
      expect(contError.stackTrace, same(originalStack));
      expect(
        contError.stackTrace.toString(),
        equals(originalStack.toString()),
      );
    });

    test('handles null-like error values', () {
      // While Object type doesn't allow null, we test edge cases
      const contError = ContError('', StackTrace.empty);

      expect(contError.error, equals(''));
      expect(contError.error, isNot(null));
    });

    test('supports different error types in list', () {
      final errors = [
        ContError(Exception('ex1'), StackTrace.empty),
        ContError('string error', StackTrace.empty),
        ContError(ArgumentError('arg'), StackTrace.empty),
        ContError(
          CustomError('custom', 1),
          StackTrace.empty,
        ),
      ];

      expect(errors.length, 4);
      expect(errors[0].error, isA<Exception>());
      expect(errors[1].error, isA<String>());
      expect(errors[2].error, isA<ArgumentError>());
      expect(errors[3].error, isA<CustomError>());
    });

    test('can be used in termination', () {
      final errors = [
        ContError('error1', StackTrace.current),
        ContError('error2', StackTrace.current),
      ];

      List<ContError>? received;
      Cont.terminate<(), int>(
        errors,
      ).run((), onTerminate: (e) => received = e);

      expect(received!.length, 2);
      expect(received![0].error, 'error1');
      expect(received![1].error, 'error2');
    });
  });
}

// Custom error class for testing
class CustomError {
  final String message;
  final int code;

  const CustomError(this.message, this.code);

  @override
  String toString() =>
      'CustomError: $message (code: $code)';
}
