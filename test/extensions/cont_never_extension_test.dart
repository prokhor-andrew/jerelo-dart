import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.absurdify', () {
    test('widens Cont with Never types via absurdify', () {
      final neverCont = Cont.fromRun<(), Never, Never>(
        (runtime, observer) {
          // never completes
        },
      );

      // absurdify is a no-op when types are already widened
      final widened = neverCont.absurdify();

      expect(widened, isA<Cont<(), Never, Never>>());
    });

    test('elseAbsurd widens Never error type', () {
      int? value;

      final neverErrorCont = Cont.of<(), Never, int>(42);
      final widened = neverErrorCont.elseAbsurd<String>();

      widened.run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('thenAbsurd widens Never value type', () {
      String? error;

      final neverValueCont =
          Cont.error<(), String, Never>('err');
      final widened = neverValueCont.thenAbsurd<int>();

      widened.run((), onElse: (e) => error = e);

      expect(error, 'err');
    });

    test('absurdify is idempotent on normal types', () {
      int? value;

      final cont = Cont.of<(), String, int>(42);
      final absurdified = cont.absurdify();

      absurdified.run((), onThen: (val) => value = val);

      expect(value, 42);
    });
  });
}
