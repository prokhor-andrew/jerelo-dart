import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseWhile', () {
    test('repeats while predicate is true', () {
      int count = 0;
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        if (count < 3) {
          observer.onElse('retry:$count');
        } else {
          observer.onThen(count);
        }
      }).elseWhile((e) => e.startsWith('retry')).run(
        (),
        onThen: (v) => result = v,
      );

      expect(count, equals(3));
      expect(result, equals(3));
    });

    test('executes at least once', () {
      int count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('stop');
      })
          .elseWhile((_) => false)
          .run((), onElse: (e) => error = e);

      expect(count, equals(1));
      expect(error, equals('stop'));
    });

    test('stops on value', () {
      int count = 0;
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onThen(count);
      })
          .elseWhile((_) => true)
          .run((), onThen: (v) => result = v);

      expect(count, equals(1));
      expect(result, equals(1));
    });

    test('can be run multiple times', () {
      int totalCount = 0;
      String? lastError;

      final cont = Cont.fromRun<(), String, int>(
          (runtime, observer) {
        totalCount++;
        if (totalCount % 3 == 0) {
          observer.onElse('done:$totalCount');
        } else {
          observer.onElse('retry');
        }
      }).elseWhile((e) => e == 'retry');

      cont.run((), onElse: (e) => lastError = e);
      expect(lastError, equals('done:3'));

      cont.run((), onElse: (e) => lastError = e);
      expect(lastError, equals('done:6'));
    });
  });

  group('Cont.elseWhile0', () {
    test('repeats while zero-arg predicate is true', () {
      int count = 0;
      int? result;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        if (count < 3) {
          observer.onElse('retry');
        } else {
          observer.onThen(count);
        }
      })
          .elseWhile0(() => count < 3)
          .run((), onThen: (v) => result = v);

      expect(count, equals(3));
      expect(result, equals(3));
    });
  });
}
