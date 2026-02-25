import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenWhile', () {
    test('repeats while predicate is true', () {
      var count = 0;
      int? value;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onThen(count);
      }).thenWhile((a) => a < 3).run(
        (),
        onThen: (val) => value = val,
      );

      expect(count, 3);
      expect(value, 3);
    });

    test('executes at least once', () {
      var callCount = 0;
      int? value;

      Cont.fromRun<(), String, int>((runtime, observer) {
        callCount++;
        observer.onThen(100);
      }).thenWhile((a) => a < 0).run(
        (),
        onThen: (val) => value = val,
      );

      expect(callCount, 1);
      expect(value, 100);
    });

    test('stops on error', () {
      var count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        if (count == 2) {
          observer.onElse('err at $count');
        } else {
          observer.onThen(count);
        }
      }).thenWhile((a) => a < 5).run(
        (),
        onElse: (e) => error = e,
      );

      expect(count, 2);
      expect(error, 'err at 2');
    });

    test('can be run multiple times', () {
      var count = 0;
      final cont = Cont.fromRun<(), String, int>(
          (runtime, observer) {
        count++;
        observer.onThen(count);
      }).thenWhile((a) => a < 2);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 2);

      // Second run: count starts at 2, increments to 3, 3 < 2 is false, returns 3
      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 3);
    });
  });

  group('Cont.thenWhile0', () {
    test('repeats while zero-arg predicate is true', () {
      var count = 0;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onThen(count);
      }).thenWhile0(() => count < 3).run(());

      expect(count, 3);
    });
  });
}
