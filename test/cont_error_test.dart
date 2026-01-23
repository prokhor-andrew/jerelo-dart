import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('ContError', () {
    group('constructor', () {
      test('stores error and stackTrace correctly', () {
        final error = Exception('test error');
        final stackTrace = StackTrace.current;

        final contError = ContError(error, stackTrace);

        expect(contError.error, equals(error));
        expect(contError.stackTrace, equals(stackTrace));
      });

      test('handles string error', () {
        const error = 'simple string error';
        final stackTrace = StackTrace.current;

        final contError = ContError(error, stackTrace);

        expect(contError.error, equals(error));
        expect(contError.stackTrace, equals(stackTrace));
      });

      test('handles int error', () {
        const error = 42;
        final stackTrace = StackTrace.current;

        final contError = ContError(error, stackTrace);

        expect(contError.error, equals(error));
      });

      test('handles null-like values as error', () {
        final stackTrace = StackTrace.current;

        final contError = ContError('null', stackTrace);

        expect(contError.error, equals('null'));
      });

      test('handles custom error objects', () {
        final customError = _CustomError('custom message');
        final stackTrace = StackTrace.current;

        final contError = ContError(customError, stackTrace);

        expect(contError.error, equals(customError));
        expect((contError.error as _CustomError).message, equals('custom message'));
      });

      test('handles Error subclass', () {
        final error = StateError('state error');
        final stackTrace = StackTrace.current;

        final contError = ContError(error, stackTrace);

        expect(contError.error, isA<StateError>());
      });

      test('handles empty StackTrace', () {
        final error = Exception('test');
        final stackTrace = StackTrace.empty;

        final contError = ContError(error, stackTrace);

        expect(contError.stackTrace, equals(StackTrace.empty));
      });

      test('preserves identity of error object', () {
        final error = _MutableError();
        error.value = 10;
        final stackTrace = StackTrace.current;

        final contError = ContError(error, stackTrace);
        (contError.error as _MutableError).value = 20;

        expect(error.value, equals(20));
      });
    });

    group('const constructor', () {
      test('can be used in const context with const values', () {
        const error = 'const error';
        const contError = ContError(error, StackTrace.empty);

        expect(contError.error, equals('const error'));
        expect(contError.stackTrace, equals(StackTrace.empty));
      });
    });

    group('equality', () {
      test('different instances with same values are not equal by default', () {
        final error = Exception('test');
        final stackTrace = StackTrace.current;

        final contError1 = ContError(error, stackTrace);
        final contError2 = ContError(error, stackTrace);

        expect(identical(contError1, contError2), isFalse);
      });

      test('same instance is equal to itself', () {
        final error = Exception('test');
        final stackTrace = StackTrace.current;

        final contError = ContError(error, stackTrace);

        expect(identical(contError, contError), isTrue);
      });
    });
  });
}

class _CustomError {
  final String message;
  _CustomError(this.message);
}

class _MutableError {
  int value = 0;
}
