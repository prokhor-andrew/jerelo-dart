import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenUntil', () {
    test('repeats until predicate is true', () {
      int count = 0;
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onThen(count);
      })
          .thenUntil((v) => v >= 3)
          .run((), onThen: (v) => result = v);

      expect(count, equals(3));
      expect(result, equals(3));
    });

    test('executes at least once', () {
      int count = 0;
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onThen(count);
      })
          .thenUntil((_) => true)
          .run((), onThen: (v) => result = v);

      expect(count, equals(1));
      expect(result, equals(1));
    });

    test('stops on error', () {
      int count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        if (count >= 2) {
          observer.onElse('stopped');
        } else {
          observer.onThen(count);
        }
      })
          .thenUntil((_) => false)
          .run((), onElse: (e) => error = e);

      expect(count, equals(2));
      expect(error, equals('stopped'));
    });

    test('can be run multiple times', () {
      int totalCount = 0;
      int? lastResult;

      final cont = Cont.fromRun<(), String, int>(
          (runtime, observer) {
        totalCount++;
        observer.onThen(totalCount);
      }).thenUntil((v) => v % 3 == 0);

      cont.run((), onThen: (v) => lastResult = v);
      expect(lastResult, equals(3));

      cont.run((), onThen: (v) => lastResult = v);
      expect(lastResult, equals(6));
    });
  });

  group('Cont.thenUntil0', () {
    test('repeats until zero-arg predicate is true', () {
      int count = 0;
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onThen(count);
      })
          .thenUntil0(() => count >= 3)
          .run((), onThen: (v) => result = v);

      expect(count, equals(3));
      expect(result, equals(3));
    });
  });
}
