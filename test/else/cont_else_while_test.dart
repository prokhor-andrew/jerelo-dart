import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseWhile', () {
    test('repeats while predicate is true', () {
      var count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('err$count');
      }).elseWhile((e) => count < 3).run(
            (),
            onElse: (e) => error = e,
          );

      expect(count, 3);
      expect(error, 'err3');
    });

    test('executes at least once', () {
      var callCount = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        callCount++;
        observer.onElse('done');
      }).elseWhile((e) => false).run(
            (),
            onElse: (e) => error = e,
          );

      expect(callCount, 1);
      expect(error, 'done');
    });

    test('stops on value', () {
      var count = 0;
      int? value;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        if (count == 2) {
          observer.onThen(count);
        } else {
          observer.onElse('err$count');
        }
      }).elseWhile((e) => count < 5).run(
            (),
            onThen: (val) => value = val,
          );

      expect(count, 2);
      expect(value, 2);
    });

    test('can be run multiple times', () {
      var count = 0;
      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('err$count');
      }).elseWhile((e) => count % 2 != 0);

      String? error1;
      cont.run((), onElse: (e) => error1 = e);
      expect(error1, 'err2');

      String? error2;
      cont.run((), onElse: (e) => error2 = e);
      expect(error2, 'err4');
    });
  });

  group('Cont.elseWhile0', () {
    test('repeats while zero-arg predicate is true', () {
      var count = 0;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('err$count');
      }).elseWhile0(() => count < 3).run(());

      expect(count, 3);
    });
  });
}
