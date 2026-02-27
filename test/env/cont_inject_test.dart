import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenInject', () {
    test('injects value as environment', () {
      int? result;

      Cont.of<(), String, int>(42)
          .thenInject(Cont.askThen<int, String>())
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('passes through source error', () {
      String? error;

      Cont.error<(), String, int>('source error')
          .thenInject(Cont.askThen<int, String>())
          .run((), onElse: (e) => error = e);

      expect(error, equals('source error'));
    });

    test('passes through target error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenInject(
              Cont.error<int, String, int>('target error'))
          .run((), onElse: (e) => error = e);

      expect(error, equals('target error'));
    });

    test('never executes target on source failure', () {
      bool targetExecuted = false;

      Cont.error<(), String, int>('source error')
          .thenInject(
        Cont.fromRun<int, String, int>((runtime, observer) {
          targetExecuted = true;
          observer.onThen(0);
        }),
      ).run(());

      expect(targetExecuted, isFalse);
    });

    test('supports type transformation', () {
      String? result;

      Cont.of<(), Never, int>(42).thenInject(
        Cont.fromRun<int, Never, String>(
            (runtime, observer) {
          observer.onThen('value:${runtime.env()}');
        }),
      ).run((), onThen: (v) => result = v);

      expect(result, equals('value:42'));
    });

    test('supports multiple runs', () {
      int? first;
      int? second;

      final source = Cont.of<(), Never, int>(5);
      final target = Cont.askThen<int, Never>();
      final cont = source.thenInject(target);

      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(5));
      expect(second, equals(5));
    });
  });
}
