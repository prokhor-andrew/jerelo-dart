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

    test('handles empty StackTrace', () {
      final error = Exception('test');

      final contError = ContError(error, StackTrace.empty);

      expect(
        contError.stackTrace,
        equals(StackTrace.empty),
      );
    });

    test('can be used in const context', () {
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
  });
}
