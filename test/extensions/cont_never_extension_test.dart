import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.absurdify', () {
    test('widens Cont with Never types via absurdify', () {
      int? result;

      // Cont<(), Never, int> used where Cont<(), String, int> is expected
      final Cont<(), String, int> widened =
          Cont.of<(), Never, int>(42).absurdify();
      widened.run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('elseAbsurd widens Never error type', () {
      int? result;

      // Cont<(), Never, int>.elseAbsurd<String>() = Cont<(), String, int>
      Cont.of<(), Never, int>(42)
          .elseAbsurd<String>()
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('thenAbsurd widens Never value type', () {
      String? error;

      // Cont<(), String, Never>.thenAbsurd<int>() = Cont<(), String, int>
      Cont.error<(), String, Never>('oops')
          .thenAbsurd<int>()
          .run((), onElse: (e) => error = e);

      expect(error, equals('oops'));
    });

    test('absurdify is idempotent on normal types', () {
      int? result;

      Cont.of<(), String, int>(42)
          .absurdify()
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });
  });
}
