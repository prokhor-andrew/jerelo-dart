import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseUntil', () {
    test('repeats until predicate is true', () {
      int count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('error:$count');
      })
          .elseUntil((e) => e == 'error:3')
          .run((), onElse: (e) => error = e);

      expect(count, equals(3));
      expect(error, equals('error:3'));
    });

    test('executes at least once', () {
      int count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('stop');
      })
          .elseUntil((_) => true)
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
          .elseUntil((_) => false)
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
        observer.onElse('error:$totalCount');
      }).elseUntil((e) => e == 'error:3' || e == 'error:6');

      cont.run((), onElse: (e) => lastError = e);
      expect(lastError, equals('error:3'));

      cont.run((), onElse: (e) => lastError = e);
      expect(lastError, equals('error:6'));
    });
  });

  group('Cont.elseUntil0', () {
    test('repeats until zero-arg predicate is true', () {
      int count = 0;
      String? error;

      Cont.fromRun<(), String, int>((runtime, observer) {
        count++;
        observer.onElse('error');
      })
          .elseUntil0(() => count >= 3)
          .run((), onElse: (e) => error = e);

      expect(count, equals(3));
      expect(error, equals('error'));
    });
  });
}
