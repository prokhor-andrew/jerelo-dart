import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.flatten', () {
    test('unwraps nested Cont with value', () {
      int? value;

      Cont.of<(), String, Cont<(), String, int>>(
        Cont.of(42),
      ).flatten().run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('unwraps nested Cont with error', () {
      String? error;

      Cont.of<(), String, Cont<(), String, int>>(
        Cont.error('inner err'),
      ).flatten().run((), onElse: (e) => error = e);

      expect(error, 'inner err');
    });

    test('passes through outer error', () {
      String? error;

      Cont.error<(), String, Cont<(), String, int>>('outer err')
          .flatten()
          .run((), onElse: (e) => error = e);

      expect(error, 'outer err');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, Cont<(), String, int>>(
        Cont.fromRun((runtime, observer) {
          callCount++;
          observer.onThen(42);
        }),
      ).flatten();

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 42);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 42);
      expect(callCount, 2);
    });
  });
}
