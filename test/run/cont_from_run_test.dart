import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromRun', () {
    test('produces value via onThen', () {
      int? value;

      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onThen(42);
      }).run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('produces error via onElse', () {
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onElse('err');
      }).run((), onElse: (e) => error = e);

      expect(error, 'err');
    });

    test('catches thrown exceptions as crashes', () {
      ContCrash? crash;

      Cont.fromRun<(), String, int>((runtime, observer) {
        throw 'Run Error';
      }).run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Run Error');
    });

    test('provides environment via runtime', () {
      int? value;

      Cont.fromRun<int, String, int>((runtime, observer) {
        observer.onThen(runtime.env() * 2);
      }).run(5, onThen: (val) => value = val);

      expect(value, 10);
    });

    test('ignores duplicate onThen calls', () {
      final values = <int>[];

      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onThen(1);
        observer.onThen(2);
        observer.onThen(3);
      }).run((), onThen: (val) => values.add(val));

      expect(values, [1]);
    });

    test('ignores callbacks after first onElse', () {
      final errors = <String>[];
      final values = <int>[];

      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onElse('err');
        observer.onThen(42);
        observer.onElse('err2');
      }).run(
        (),
        onElse: (e) => errors.add(e),
        onThen: (val) => values.add(val),
      );

      expect(errors, ['err']);
      expect(values, isEmpty);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
        callCount++;
        observer.onThen(callCount);
      });

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 1);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 2);
      expect(callCount, 2);
    });

    test('supports cancellation', () {
      int? value;

      final List<void Function()> buffer = [];
      void flush() {
        for (final v in buffer) {
          v();
        }
        buffer.clear();
      }

      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          observer.onThen(42);
        });
      });

      final token = cont.run(
        (),
        onThen: (val) => value = val,
      );
      token.cancel();
      flush();

      expect(value, null);
    });
  });
}
