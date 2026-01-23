import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('ContScheduler', () {
    group('immediate', () {
      test('executes action synchronously', () {
        var executed = false;

        ContScheduler.immediate.schedule(() {
          executed = true;
        });

        expect(executed, isTrue);
      });

      test('executes actions in order', () {
        final order = <int>[];

        ContScheduler.immediate.schedule(() => order.add(1));
        ContScheduler.immediate.schedule(() => order.add(2));
        ContScheduler.immediate.schedule(() => order.add(3));

        expect(order, equals([1, 2, 3]));
      });

      test('can be used multiple times', () {
        var count = 0;

        for (var i = 0; i < 10; i++) {
          ContScheduler.immediate.schedule(() => count++);
        }

        expect(count, equals(10));
      });

      test('action can throw exception', () {
        expect(
          () => ContScheduler.immediate.schedule(() {
            throw Exception('test');
          }),
          throwsException,
        );
      });

      test('is const', () {
        expect(identical(ContScheduler.immediate, ContScheduler.immediate), isTrue);
      });
    });

    group('fromSchedule', () {
      test('creates scheduler with custom schedule function', () {
        var executed = false;

        final scheduler = ContScheduler.fromSchedule((action) {
          executed = true;
          action();
        });

        scheduler.schedule(() {});

        expect(executed, isTrue);
      });

      test('custom scheduler can delay execution', () {
        final queue = <void Function()>[];

        final scheduler = ContScheduler.fromSchedule((action) {
          queue.add(action);
        });

        var executed = false;
        scheduler.schedule(() => executed = true);

        expect(executed, isFalse);
        expect(queue.length, equals(1));

        queue[0]();
        expect(executed, isTrue);
      });

      test('custom scheduler can modify actions', () {
        var callCount = 0;

        final scheduler = ContScheduler.fromSchedule((action) {
          callCount++;
          action();
          action();
        });

        var actionCount = 0;
        scheduler.schedule(() => actionCount++);

        expect(callCount, equals(1));
        expect(actionCount, equals(2));
      });

      test('custom scheduler can ignore actions', () {
        final scheduler = ContScheduler.fromSchedule((action) {
          // Intentionally do nothing
        });

        var executed = false;
        scheduler.schedule(() => executed = true);

        expect(executed, isFalse);
      });
    });

    group('delayed', () {
      test('creates scheduler with zero delay by default', () async {
        var executed = false;

        ContScheduler.delayed().schedule(() {
          executed = true;
        });

        expect(executed, isFalse);

        await Future.delayed(Duration.zero);

        expect(executed, isTrue);
      });

      test('creates scheduler with specified delay', () async {
        var executed = false;

        ContScheduler.delayed(const Duration(milliseconds: 50)).schedule(() {
          executed = true;
        });

        expect(executed, isFalse);

        await Future.delayed(const Duration(milliseconds: 25));
        expect(executed, isFalse);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(executed, isTrue);
      });

      test('multiple delayed actions maintain order with same delay', () async {
        final order = <int>[];

        final scheduler = ContScheduler.delayed(const Duration(milliseconds: 10));

        scheduler.schedule(() => order.add(1));
        scheduler.schedule(() => order.add(2));
        scheduler.schedule(() => order.add(3));

        expect(order, isEmpty);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(order, equals([1, 2, 3]));
      });

      test('different schedulers with different delays', () async {
        final order = <int>[];

        ContScheduler.delayed(const Duration(milliseconds: 30)).schedule(() {
          order.add(2);
        });

        ContScheduler.delayed(const Duration(milliseconds: 10)).schedule(() {
          order.add(1);
        });

        await Future.delayed(const Duration(milliseconds: 100));

        expect(order, equals([1, 2]));
      });
    });

    group('microtask', () {
      test('creates scheduler that uses microtask queue', () async {
        var executed = false;

        ContScheduler.microtask().schedule(() {
          executed = true;
        });

        expect(executed, isFalse);

        await Future.microtask(() {});

        expect(executed, isTrue);
      });

      test('microtask executes before delayed(Duration.zero)', () async {
        final order = <int>[];

        ContScheduler.delayed().schedule(() {
          order.add(2);
        });

        ContScheduler.microtask().schedule(() {
          order.add(1);
        });

        await Future.delayed(const Duration(milliseconds: 10));

        expect(order, equals([1, 2]));
      });

      test('multiple microtask actions maintain order', () async {
        final order = <int>[];

        final scheduler = ContScheduler.microtask();

        scheduler.schedule(() => order.add(1));
        scheduler.schedule(() => order.add(2));
        scheduler.schedule(() => order.add(3));

        expect(order, isEmpty);

        await Future.microtask(() {});
        await Future.microtask(() {});
        await Future.microtask(() {});

        expect(order, equals([1, 2, 3]));
      });
    });
  });

  group('TestContScheduler', () {
    group('constructor', () {
      test('creates scheduler with empty queue', () {
        final testScheduler = TestContScheduler();

        expect(testScheduler.pendingCount(), equals(0));
        expect(testScheduler.isIdle(), isTrue);
      });
    });

    group('asScheduler', () {
      test('returns ContScheduler that enqueues actions', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        var executed = false;
        scheduler.schedule(() => executed = true);

        expect(executed, isFalse);
        expect(testScheduler.pendingCount(), equals(1));
      });

      test('multiple calls return schedulers using same queue', () {
        final testScheduler = TestContScheduler();
        final scheduler1 = testScheduler.asScheduler();
        final scheduler2 = testScheduler.asScheduler();

        scheduler1.schedule(() {});
        scheduler2.schedule(() {});

        expect(testScheduler.pendingCount(), equals(2));
      });
    });

    group('pendingCount', () {
      test('returns 0 for empty queue', () {
        final testScheduler = TestContScheduler();

        expect(testScheduler.pendingCount(), equals(0));
      });

      test('returns correct count after scheduling', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        scheduler.schedule(() {});
        expect(testScheduler.pendingCount(), equals(1));

        scheduler.schedule(() {});
        expect(testScheduler.pendingCount(), equals(2));

        scheduler.schedule(() {});
        expect(testScheduler.pendingCount(), equals(3));
      });

      test('returns correct count after partial flush', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        scheduler.schedule(() {});
        scheduler.schedule(() {});
        scheduler.schedule(() {});

        testScheduler.flush(2);

        expect(testScheduler.pendingCount(), equals(1));
      });

      test('returns 0 after full flush', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        scheduler.schedule(() {});
        scheduler.schedule(() {});

        testScheduler.flush();

        expect(testScheduler.pendingCount(), equals(0));
      });
    });

    group('isIdle', () {
      test('returns true for empty queue', () {
        final testScheduler = TestContScheduler();

        expect(testScheduler.isIdle(), isTrue);
      });

      test('returns false when actions are queued', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        scheduler.schedule(() {});

        expect(testScheduler.isIdle(), isFalse);
      });

      test('returns true after flush', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        scheduler.schedule(() {});
        testScheduler.flush();

        expect(testScheduler.isIdle(), isTrue);
      });
    });

    group('flush', () {
      test('executes all queued actions', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        scheduler.schedule(() => order.add(1));
        scheduler.schedule(() => order.add(2));
        scheduler.schedule(() => order.add(3));

        testScheduler.flush();

        expect(order, equals([1, 2, 3]));
      });

      test('executes actions in FIFO order', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        for (var i = 1; i <= 5; i++) {
          final value = i;
          scheduler.schedule(() => order.add(value));
        }

        testScheduler.flush();

        expect(order, equals([1, 2, 3, 4, 5]));
      });

      test('handles empty queue gracefully', () {
        final testScheduler = TestContScheduler();

        expect(() => testScheduler.flush(), returnsNormally);
      });

      test('with maxSteps limits execution', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        scheduler.schedule(() => order.add(1));
        scheduler.schedule(() => order.add(2));
        scheduler.schedule(() => order.add(3));
        scheduler.schedule(() => order.add(4));
        scheduler.schedule(() => order.add(5));

        testScheduler.flush(3);

        expect(order, equals([1, 2, 3]));
        expect(testScheduler.pendingCount(), equals(2));
      });

      test('with maxSteps of 0 executes nothing', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        scheduler.schedule(() => order.add(1));
        scheduler.schedule(() => order.add(2));

        testScheduler.flush(0);

        expect(order, isEmpty);
        expect(testScheduler.pendingCount(), equals(2));
      });

      test('with maxSteps of -1 executes all (unlimited)', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        for (var i = 1; i <= 100; i++) {
          final value = i;
          scheduler.schedule(() => order.add(value));
        }

        testScheduler.flush(-1);

        expect(order.length, equals(100));
      });

      test('handles self-enqueuing actions with maxSteps', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        var count = 0;

        void enqueue() {
          scheduler.schedule(() {
            count++;
            if (count < 100) {
              enqueue();
            }
          });
        }

        enqueue();

        testScheduler.flush(10);

        expect(count, equals(10));
        expect(testScheduler.isIdle(), isFalse);
      });

      test('can be called multiple times', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        scheduler.schedule(() => order.add(1));
        testScheduler.flush();

        scheduler.schedule(() => order.add(2));
        testScheduler.flush();

        scheduler.schedule(() => order.add(3));
        testScheduler.flush();

        expect(order, equals([1, 2, 3]));
      });

      test('handles exceptions in actions', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        scheduler.schedule(() {
          throw Exception('test');
        });

        expect(() => testScheduler.flush(), throwsException);
      });

      test('handles action that schedules more actions', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        scheduler.schedule(() {
          order.add(1);
          scheduler.schedule(() {
            order.add(3);
          });
        });

        scheduler.schedule(() {
          order.add(2);
        });

        testScheduler.flush();

        expect(order, equals([1, 2, 3]));
      });
    });

    group('integration with Cont', () {
      test('can control Cont execution timing', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        int? result;

        Cont.of(42).subscribeOn(scheduler).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, isNull);

        testScheduler.flush();

        expect(result, equals(42));
      });

      test('can control observation timing', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        int? result;

        Cont.of(42).observeOn(scheduler).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, isNull);

        testScheduler.flush();

        expect(result, equals(42));
      });

      test('can step through chained operations', () {
        final subscribeScheduler = TestContScheduler();
        final observeScheduler = TestContScheduler();
        final order = <String>[];

        Cont.of(1)
            .subscribeOn(subscribeScheduler.asScheduler())
            .map((x) {
              order.add('map1');
              return x * 2;
            })
            .map((x) {
              order.add('map2');
              return x * 2;
            })
            .observeOn(observeScheduler.asScheduler())
            .run(
              (errors) {},
              (value) => order.add('result: $value'),
            );

        expect(order, isEmpty);

        subscribeScheduler.flush();
        expect(order, equals(['map1', 'map2']));

        observeScheduler.flush();
        expect(order, equals(['map1', 'map2', 'result: 4']));
      });

      test('can test parallel execution', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <String>[];

        final left = Cont.of(1).subscribeOn(scheduler).map((x) {
          order.add('left');
          return x;
        });

        final right = Cont.of(2).subscribeOn(scheduler).map((x) {
          order.add('right');
          return x;
        });

        Cont.both(left, right, (a, b) => a + b).run(
          (errors) {},
          (value) => order.add('result: $value'),
        );

        expect(order, isEmpty);

        testScheduler.flush(1);
        expect(order, equals(['left']));

        testScheduler.flush(1);
        expect(order, equals(['left', 'right', 'result: 3']));
      });

      test('can test error handling', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();

        List<ContError>? errors;

        Cont.terminate<int>([ContError('test error', StackTrace.current)])
            .observeOn(scheduler)
            .run(
              (e) => errors = e,
              (value) {},
            );

        expect(errors, isNull);

        testScheduler.flush();

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
        expect(errors![0].error, equals('test error'));
      });

      test('can test sequence execution step by step', () {
        final testScheduler = TestContScheduler();
        final scheduler = testScheduler.asScheduler();
        final order = <int>[];

        final conts = [
          Cont.of(1).subscribeOn(scheduler).map((x) {
            order.add(x);
            return x;
          }),
          Cont.of(2).subscribeOn(scheduler).map((x) {
            order.add(x);
            return x;
          }),
          Cont.of(3).subscribeOn(scheduler).map((x) {
            order.add(x);
            return x;
          }),
        ];

        Cont.sequence(conts).run(
          (errors) {},
          (values) => order.add(values.reduce((a, b) => a + b)),
        );

        expect(order, isEmpty);

        testScheduler.flush(1);
        expect(order, equals([1]));

        testScheduler.flush(1);
        expect(order, equals([1, 2]));

        testScheduler.flush(1);
        expect(order, equals([1, 2, 3, 6]));
      });
    });
  });
}
