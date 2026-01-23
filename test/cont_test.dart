import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont', () {
    group('of', () {
      test('creates Cont with value', () {
        int? result;

        Cont.of(42).run(
          (errors) => fail('Should not terminate'),
          (value) => result = value,
        );

        expect(result, equals(42));
      });

      test('works with different types', () {
        String? stringResult;
        Cont.of('hello').run(
          (errors) => fail('Should not terminate'),
          (value) => stringResult = value,
        );
        expect(stringResult, equals('hello'));

        List<int>? listResult;
        Cont.of([1, 2, 3]).run(
          (errors) => fail('Should not terminate'),
          (value) => listResult = value,
        );
        expect(listResult, equals([1, 2, 3]));
      });

      test('works with null value', () {
        int? result;
        var valueCalled = false;

        Cont.of<int?>(null).run(
          (errors) => fail('Should not terminate'),
          (value) {
            valueCalled = true;
            result = value;
          },
        );

        expect(valueCalled, isTrue);
        expect(result, isNull);
      });
    });

    group('terminate', () {
      test('creates Cont that terminates with empty errors by default', () {
        List<ContError>? errors;

        Cont.terminate<int>().run(
          (e) => errors = e,
          (value) => fail('Should not produce value'),
        );

        expect(errors, isNotNull);
        expect(errors, isEmpty);
      });

      test('creates Cont that terminates with provided errors', () {
        final error1 = ContError('error1', StackTrace.current);
        final error2 = ContError('error2', StackTrace.current);

        List<ContError>? errors;

        Cont.terminate<int>([error1, error2]).run(
          (e) => errors = e,
          (value) => fail('Should not produce value'),
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(2));
      });

      test('makes defensive copy of errors list', () {
        final originalErrors = [ContError('error', StackTrace.current)];

        List<ContError>? received;

        Cont.terminate<int>(originalErrors).run(
          (e) => received = e,
          (value) {},
        );

        originalErrors.add(ContError('another', StackTrace.current));

        expect(received!.length, equals(1));
      });
    });

    group('fromRun', () {
      test('creates Cont with custom run function', () {
        int? result;

        Cont.fromRun<int>((observer) {
          observer.onValue(100);
        }).run(
          (errors) => fail('Should not terminate'),
          (value) => result = value,
        );

        expect(result, equals(100));
      });

      test('catches exceptions and converts to errors', () {
        List<ContError>? errors;

        Cont.fromRun<int>((observer) {
          throw Exception('test exception');
        }).run(
          (e) => errors = e,
          (value) => fail('Should not produce value'),
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
        expect(errors![0].error.toString(), contains('test exception'));
      });

      test('provides idempotence - ignores multiple onValue calls', () {
        var valueCount = 0;

        Cont.fromRun<int>((observer) {
          observer.onValue(1);
          observer.onValue(2);
          observer.onValue(3);
        }).run(
          (errors) {},
          (value) => valueCount++,
        );

        expect(valueCount, equals(1));
      });

      test('provides idempotence - ignores onValue after onTerminate', () {
        var valueCalled = false;
        var terminateCalled = false;

        Cont.fromRun<int>((observer) {
          observer.onTerminate([]);
          observer.onValue(1);
        }).run(
          (errors) => terminateCalled = true,
          (value) => valueCalled = true,
        );

        expect(terminateCalled, isTrue);
        expect(valueCalled, isFalse);
      });

      test('provides idempotence - ignores onTerminate after onValue', () {
        var valueCalled = false;
        var terminateCalled = false;

        Cont.fromRun<int>((observer) {
          observer.onValue(1);
          observer.onTerminate([]);
        }).run(
          (errors) => terminateCalled = true,
          (value) => valueCalled = true,
        );

        expect(valueCalled, isTrue);
        expect(terminateCalled, isFalse);
      });

      test('makes defensive copy of errors', () {
        final errors = [ContError('original', StackTrace.current)];
        List<ContError>? received;

        Cont.fromRun<int>((observer) {
          observer.onTerminate(errors);
        }).run(
          (e) => received = e,
          (value) {},
        );

        errors.add(ContError('added', StackTrace.current));

        expect(received!.length, equals(1));
      });
    });

    group('fromDeferred', () {
      test('lazily evaluates the inner Cont', () {
        var evaluated = false;

        final cont = Cont.fromDeferred(() {
          evaluated = true;
          return Cont.of(42);
        });

        expect(evaluated, isFalse);

        int? result;
        cont.run(
          (errors) {},
          (value) => result = value,
        );

        expect(evaluated, isTrue);
        expect(result, equals(42));
      });

      test('catches exceptions in thunk', () {
        List<ContError>? errors;

        Cont.fromDeferred<int>(() {
          throw Exception('thunk error');
        }).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('creates new Cont on each run', () {
        var count = 0;

        final cont = Cont.fromDeferred(() {
          count++;
          return Cont.of(count);
        });

        int? result1;
        int? result2;

        cont.run((errors) {}, (value) => result1 = value);
        cont.run((errors) {}, (value) => result2 = value);

        expect(result1, equals(1));
        expect(result2, equals(2));
      });
    });

    group('fromFutureComp', () {
      test('converts successful Future to Cont', () async {
        final completer = Completer<int>();

        int? result;
        var done = false;

        Cont.fromFutureComp(() => completer.future).run(
          (errors) => fail('Should not terminate'),
          (value) {
            result = value;
            done = true;
          },
        );

        expect(done, isFalse);

        completer.complete(42);
        await Future.microtask(() {});

        expect(done, isTrue);
        expect(result, equals(42));
      });

      test('converts Future error to termination', () async {
        final completer = Completer<int>();

        List<ContError>? errors;
        var done = false;

        Cont.fromFutureComp(() => completer.future).run(
          (e) {
            errors = e;
            done = true;
          },
          (value) => fail('Should not produce value'),
        );

        expect(done, isFalse);

        completer.completeError(Exception('future error'));
        await Future.microtask(() {});

        expect(done, isTrue);
        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('catches synchronous exceptions in thunk', () async {
        List<ContError>? errors;

        Cont.fromFutureComp<int>(() {
          throw Exception('sync error');
        }).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });
    });

    group('map', () {
      test('transforms value', () {
        int? result;

        Cont.of(10).map((x) => x * 2).run(
          (errors) => fail('Should not terminate'),
          (value) => result = value,
        );

        expect(result, equals(20));
      });

      test('preserves termination', () {
        List<ContError>? errors;

        Cont.terminate<int>([ContError('error', StackTrace.current)])
            .map((x) => x * 2)
            .run(
              (e) => errors = e,
              (value) => fail('Should not produce value'),
            );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('catches exceptions in transformation', () {
        List<ContError>? errors;

        Cont.of(10).map<int>((x) {
          throw Exception('map error');
        }).run(
          (e) => errors = e,
          (value) => fail('Should not produce value'),
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('can change type', () {
        String? result;

        Cont.of(42).map((x) => 'number: $x').run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('number: 42'));
      });

      test('can be chained', () {
        int? result;

        Cont.of(1)
            .map((x) => x + 1)
            .map((x) => x * 2)
            .map((x) => x + 3)
            .run(
              (errors) {},
              (value) => result = value,
            );

        expect(result, equals(7));
      });
    });

    group('map0', () {
      test('transforms value ignoring input', () {
        String? result;

        Cont.of(42).map0(() => 'ignored input').run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('ignored input'));
      });

      test('preserves termination', () {
        var terminateCalled = false;

        Cont.terminate<int>().map0(() => 'transformed').run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });
    });

    group('mapTo', () {
      test('replaces value with constant', () {
        String? result;

        Cont.of(42).mapTo('constant').run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('constant'));
      });

      test('preserves termination', () {
        var terminateCalled = false;

        Cont.terminate<int>().mapTo('constant').run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });
    });

    group('flatMap', () {
      test('chains continuations', () {
        int? result;

        Cont.of(10).flatMap((x) => Cont.of(x * 2)).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(20));
      });

      test('propagates termination from first', () {
        var terminateCalled = false;
        var secondCalled = false;

        Cont.terminate<int>().flatMap((x) {
          secondCalled = true;
          return Cont.of(x * 2);
        }).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
        expect(secondCalled, isFalse);
      });

      test('propagates termination from second', () {
        List<ContError>? errors;

        Cont.of(10).flatMap<int>((x) {
          return Cont.terminate([ContError('second error', StackTrace.current)]);
        }).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('catches exceptions in transformation function', () {
        List<ContError>? errors;

        Cont.of(10).flatMap<int>((x) {
          throw Exception('flatMap error');
        }).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('can be deeply chained', () {
        int? result;

        Cont.of(1)
            .flatMap((x) => Cont.of(x + 1))
            .flatMap((x) => Cont.of(x * 2))
            .flatMap((x) => Cont.of(x + 3))
            .run(
              (errors) {},
              (value) => result = value,
            );

        expect(result, equals(7));
      });
    });

    group('flatMap0', () {
      test('chains ignoring first value', () {
        String? result;

        Cont.of(42).flatMap0(() => Cont.of('ignored')).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('ignored'));
      });
    });

    group('flatMapTo', () {
      test('chains to constant Cont', () {
        String? result;

        Cont.of(42).flatMapTo(Cont.of('constant')).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('constant'));
      });
    });

    group('flatTap', () {
      test('executes side effect and returns original value', () {
        int? sideEffect;
        int? result;

        Cont.of(42)
            .flatTap((x) {
              return Cont.of(x * 2).map((doubled) {
                sideEffect = doubled;
                return doubled;
              });
            })
            .run(
              (errors) {},
              (value) => result = value,
            );

        expect(sideEffect, equals(84));
        expect(result, equals(42));
      });

      test('propagates termination from side effect', () {
        var terminateCalled = false;

        Cont.of(42)
            .flatTap<int>((x) => Cont.terminate([ContError('tap error', StackTrace.current)]))
            .run(
              (errors) => terminateCalled = true,
              (value) {},
            );

        expect(terminateCalled, isTrue);
      });
    });

    group('flatTap0', () {
      test('executes side effect ignoring value', () {
        var sideEffectCalled = false;
        int? result;

        Cont.of(42)
            .flatTap0(() {
              sideEffectCalled = true;
              return Cont.of('side effect');
            })
            .run(
              (errors) {},
              (value) => result = value,
            );

        expect(sideEffectCalled, isTrue);
        expect(result, equals(42));
      });
    });

    group('flatTapTo', () {
      test('executes constant side effect Cont', () {
        var sideEffectRan = false;
        int? result;

        final sideEffect = Cont.fromRun<String>((observer) {
          sideEffectRan = true;
          observer.onValue('done');
        });

        Cont.of(42).flatTapTo(sideEffect).run(
          (errors) {},
          (value) => result = value,
        );

        expect(sideEffectRan, isTrue);
        expect(result, equals(42));
      });
    });

    group('flatMapZipWith', () {
      test('combines values from both continuations', () {
        String? result;

        Cont.of(10).flatMapZipWith(
          (x) => Cont.of(x * 2),
          (a, b) => '$a -> $b',
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('10 -> 20'));
      });

      test('propagates termination from first', () {
        var terminateCalled = false;

        Cont.terminate<int>().flatMapZipWith(
          (x) => Cont.of(x * 2),
          (a, b) => a + b,
        ).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });

      test('propagates termination from second', () {
        var terminateCalled = false;

        Cont.of(10).flatMapZipWith<int, int>(
          (x) => Cont.terminate(),
          (a, b) => a + b,
        ).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });
    });

    group('flatMapZipWith0', () {
      test('combines values with zero-arg function', () {
        String? result;

        Cont.of(10).flatMapZipWith0(
          () => Cont.of(20),
          (a, b) => '$a + $b = ${a + b}',
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('10 + 20 = 30'));
      });
    });

    group('flatMapZipWithTo', () {
      test('combines with constant Cont', () {
        String? result;

        Cont.of(10).flatMapZipWithTo(
          Cont.of(20),
          (a, b) => '$a + $b = ${a + b}',
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('10 + 20 = 30'));
      });
    });

    group('sequence', () {
      test('executes continuations in order and collects results', () {
        List<int>? result;

        Cont.sequence([
          Cont.of(1),
          Cont.of(2),
          Cont.of(3),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals([1, 2, 3]));
      });

      test('returns empty list for empty input', () {
        List<int>? result;

        Cont.sequence<int>([]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals([]));
      });

      test('terminates on first failure', () {
        final order = <int>[];
        List<ContError>? errors;

        Cont.sequence([
          Cont.of(1).map((x) {
            order.add(x);
            return x;
          }),
          Cont.terminate<int>([ContError('error at 2', StackTrace.current)]),
          Cont.of(3).map((x) {
            order.add(x);
            return x;
          }),
        ]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(order, equals([1]));
        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('handles large lists (stack safety)', () {
        final conts = List.generate(1000, (i) => Cont.of(i));

        List<int>? result;

        Cont.sequence(conts).run(
          (errors) => fail('Should not terminate'),
          (value) => result = value,
        );

        expect(result, isNotNull);
        expect(result!.length, equals(1000));
        expect(result![999], equals(999));
      });

      test('makes defensive copy of input list', () {
        final conts = [Cont.of(1), Cont.of(2)];

        List<int>? result;

        final cont = Cont.sequence(conts);

        conts.add(Cont.of(3));

        cont.run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals([1, 2]));
      });

      test('catches exceptions in continuation', () {
        List<ContError>? errors;

        Cont.sequence([
          Cont.of(1),
          Cont.fromRun<int>((observer) {
            throw Exception('sequence error');
          }),
          Cont.of(3),
        ]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });
    });

    group('orElseWith', () {
      test('uses fallback on termination', () {
        int? result;

        Cont.terminate<int>().orElseWith((errors) => Cont.of(42)).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });

      test('does not use fallback on success', () {
        var fallbackCalled = false;
        int? result;

        Cont.of(10).orElseWith((errors) {
          fallbackCalled = true;
          return Cont.of(42);
        }).run(
          (errors) {},
          (value) => result = value,
        );

        expect(fallbackCalled, isFalse);
        expect(result, equals(10));
      });

      test('accumulates errors if fallback also fails', () {
        List<ContError>? errors;

        Cont.terminate<int>([ContError('first', StackTrace.current)])
            .orElseWith((e) => Cont.terminate([ContError('second', StackTrace.current)]))
            .run(
              (e) => errors = e,
              (value) {},
            );

        expect(errors, isNotNull);
        expect(errors!.length, equals(2));
        expect(errors![0].error, equals('first'));
        expect(errors![1].error, equals('second'));
      });

      test('passes original errors to fallback function', () {
        List<ContError>? receivedErrors;

        Cont.terminate<int>([
          ContError('error1', StackTrace.current),
          ContError('error2', StackTrace.current),
        ]).orElseWith((errors) {
          receivedErrors = errors;
          return Cont.of(42);
        }).run(
          (errors) {},
          (value) {},
        );

        expect(receivedErrors, isNotNull);
        expect(receivedErrors!.length, equals(2));
      });

      test('catches exceptions in fallback function', () {
        List<ContError>? errors;

        Cont.terminate<int>([ContError('original', StackTrace.current)])
            .orElseWith((e) {
              throw Exception('fallback error');
            })
            .run(
              (e) => errors = e,
              (value) {},
            );

        expect(errors, isNotNull);
        expect(errors!.length, equals(2));
      });
    });

    group('orElseWith0', () {
      test('uses zero-arg fallback', () {
        int? result;

        Cont.terminate<int>().orElseWith0(() => Cont.of(42)).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });

    group('orElse', () {
      test('uses constant fallback Cont', () {
        int? result;

        Cont.terminate<int>().orElse(Cont.of(42)).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });

    group('orElseAll', () {
      test('succeeds with first successful Cont', () {
        int? result;

        Cont.orElseAll([
          Cont.terminate<int>([ContError('first', StackTrace.current)]),
          Cont.of(42),
          Cont.of(100),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });

      test('accumulates all errors if all fail', () {
        List<ContError>? errors;

        Cont.orElseAll([
          Cont.terminate<int>([ContError('first', StackTrace.current)]),
          Cont.terminate<int>([ContError('second', StackTrace.current)]),
          Cont.terminate<int>([ContError('third', StackTrace.current)]),
        ]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(3));
      });

      test('returns empty termination for empty list', () {
        List<ContError>? errors;

        Cont.orElseAll<int>([]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors, isEmpty);
      });

      test('handles large lists (stack safety)', () {
        final conts = [
          ...List.generate(999, (i) => Cont.terminate<int>([ContError('error $i', StackTrace.current)])),
          Cont.of(42),
        ];

        int? result;

        Cont.orElseAll(conts).run(
          (errors) => fail('Should not terminate'),
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });

    group('filter', () {
      test('passes value through if predicate returns true', () {
        int? result;

        Cont.of(42).filter((x) => x > 10).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });

      test('terminates if predicate returns false', () {
        var terminateCalled = false;

        Cont.of(5).filter((x) => x > 10).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });

      test('terminates with empty errors on filter failure', () {
        List<ContError>? errors;

        Cont.of(5).filter((x) => x > 10).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors, isEmpty);
      });

      test('propagates original termination', () {
        List<ContError>? errors;

        Cont.terminate<int>([ContError('original', StackTrace.current)])
            .filter((x) => x > 10)
            .run(
              (e) => errors = e,
              (value) {},
            );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
        expect(errors![0].error, equals('original'));
      });
    });

    group('both', () {
      test('runs both and combines results', () {
        String? result;

        Cont.both(
          Cont.of(10),
          Cont.of(20),
          (a, b) => '$a + $b = ${a + b}',
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('10 + 20 = 30'));
      });

      test('terminates if left fails', () {
        var terminateCalled = false;

        Cont.both(
          Cont.terminate<int>([ContError('left error', StackTrace.current)]),
          Cont.of(20),
          (a, b) => a + b,
        ).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });

      test('terminates if right fails', () {
        var terminateCalled = false;

        Cont.both(
          Cont.of(10),
          Cont.terminate<int>([ContError('right error', StackTrace.current)]),
          (a, b) => a + b,
        ).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });

      test('catches exception in combiner function', () {
        List<ContError>? errors;

        Cont.both<int, int, int>(
          Cont.of(10),
          Cont.of(20),
          (a, b) => throw Exception('combiner error'),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('runs both concurrently with test scheduler', () {
        final scheduler = TestContScheduler();
        final order = <String>[];

        Cont.both(
          Cont.of(10).subscribeOn(scheduler.asScheduler()).map((x) {
            order.add('left');
            return x;
          }),
          Cont.of(20).subscribeOn(scheduler.asScheduler()).map((x) {
            order.add('right');
            return x;
          }),
          (a, b) {
            order.add('combine');
            return a + b;
          },
        ).run(
          (errors) {},
          (value) => order.add('result: $value'),
        );

        expect(order, isEmpty);

        scheduler.flush(1);
        expect(order, equals(['left']));

        scheduler.flush(1);
        expect(order, equals(['left', 'right', 'combine', 'result: 30']));
      });
    });

    group('and', () {
      test('is instance method wrapper for both', () {
        String? result;

        Cont.of(10).and(Cont.of(20), (a, b) => '$a and $b').run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals('10 and 20'));
      });
    });

    group('all', () {
      test('runs all and collects results in order', () {
        List<int>? result;

        Cont.all([
          Cont.of(1),
          Cont.of(2),
          Cont.of(3),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals([1, 2, 3]));
      });

      test('returns empty list for empty input', () {
        List<int>? result;

        Cont.all<int>([]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals([]));
      });

      test('terminates if any fails', () {
        List<ContError>? errors;

        Cont.all([
          Cont.of(1),
          Cont.terminate<int>([ContError('error', StackTrace.current)]),
          Cont.of(3),
        ]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('preserves order with async completion', () {
        final scheduler1 = TestContScheduler();
        final scheduler2 = TestContScheduler();
        final scheduler3 = TestContScheduler();

        List<int>? result;

        Cont.all([
          Cont.of(1).subscribeOn(scheduler1.asScheduler()),
          Cont.of(2).subscribeOn(scheduler2.asScheduler()),
          Cont.of(3).subscribeOn(scheduler3.asScheduler()),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        scheduler3.flush();
        scheduler1.flush();
        scheduler2.flush();

        expect(result, equals([1, 2, 3]));
      });
    });

    group('raceForWinner', () {
      test('returns first successful value', () {
        final scheduler1 = TestContScheduler();
        final scheduler2 = TestContScheduler();

        int? result;

        Cont.raceForWinner(
          Cont.of(10).subscribeOn(scheduler1.asScheduler()),
          Cont.of(20).subscribeOn(scheduler2.asScheduler()),
        ).run(
          (errors) {},
          (value) => result = value,
        );

        scheduler2.flush();

        expect(result, equals(20));
      });

      test('ignores second value after first wins', () {
        final scheduler1 = TestContScheduler();
        final scheduler2 = TestContScheduler();

        int? result;
        var valueCount = 0;

        Cont.raceForWinner(
          Cont.of(10).subscribeOn(scheduler1.asScheduler()),
          Cont.of(20).subscribeOn(scheduler2.asScheduler()),
        ).run(
          (errors) {},
          (value) {
            result = value;
            valueCount++;
          },
        );

        scheduler1.flush();
        scheduler2.flush();

        expect(result, equals(10));
        expect(valueCount, equals(1));
      });

      test('succeeds if second wins when first fails', () {
        int? result;

        Cont.raceForWinner(
          Cont.terminate<int>([ContError('first', StackTrace.current)]),
          Cont.of(20),
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(20));
      });

      test('terminates with all errors if both fail', () {
        List<ContError>? errors;

        Cont.raceForWinner(
          Cont.terminate<int>([ContError('first', StackTrace.current)]),
          Cont.terminate<int>([ContError('second', StackTrace.current)]),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(2));
      });
    });

    group('raceForLoser', () {
      test('returns last value to complete', () {
        final scheduler1 = TestContScheduler();
        final scheduler2 = TestContScheduler();

        int? result;

        Cont.raceForLoser(
          Cont.of(10).subscribeOn(scheduler1.asScheduler()),
          Cont.of(20).subscribeOn(scheduler2.asScheduler()),
        ).run(
          (errors) {},
          (value) => result = value,
        );

        scheduler1.flush();
        expect(result, isNull);

        scheduler2.flush();
        expect(result, equals(20));
      });

      test('returns remaining value if one fails', () {
        int? result;

        Cont.raceForLoser(
          Cont.terminate<int>([ContError('first', StackTrace.current)]),
          Cont.of(20),
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(20));
      });

      test('terminates if both fail', () {
        List<ContError>? errors;

        Cont.raceForLoser(
          Cont.terminate<int>([ContError('first', StackTrace.current)]),
          Cont.terminate<int>([ContError('second', StackTrace.current)]),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(2));
      });
    });

    group('raceForWinnerWith', () {
      test('is instance method for raceForWinner', () {
        int? result;

        Cont.terminate<int>().raceForWinnerWith(Cont.of(42)).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });

    group('raceForLoserWith', () {
      test('is instance method for raceForLoser', () {
        final scheduler1 = TestContScheduler();
        final scheduler2 = TestContScheduler();

        int? result;

        Cont.of(10)
            .subscribeOn(scheduler1.asScheduler())
            .raceForLoserWith(Cont.of(20).subscribeOn(scheduler2.asScheduler()))
            .run(
              (errors) {},
              (value) => result = value,
            );

        scheduler1.flush();
        scheduler2.flush();

        expect(result, equals(20));
      });
    });

    group('raceForWinnerAll', () {
      test('returns first winner', () {
        final schedulers = List.generate(3, (_) => TestContScheduler());

        int? result;

        Cont.raceForWinnerAll([
          Cont.of(1).subscribeOn(schedulers[0].asScheduler()),
          Cont.of(2).subscribeOn(schedulers[1].asScheduler()),
          Cont.of(3).subscribeOn(schedulers[2].asScheduler()),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        schedulers[1].flush();

        expect(result, equals(2));
      });

      test('terminates with empty errors for empty list', () {
        List<ContError>? errors;

        Cont.raceForWinnerAll<int>([]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors, isEmpty);
      });

      test('accumulates all errors if all fail', () {
        List<ContError>? errors;

        Cont.raceForWinnerAll([
          Cont.terminate<int>([ContError('e1', StackTrace.current)]),
          Cont.terminate<int>([ContError('e2', StackTrace.current)]),
          Cont.terminate<int>([ContError('e3', StackTrace.current)]),
        ]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(3));
      });

      test('succeeds if any succeeds', () {
        int? result;

        Cont.raceForWinnerAll([
          Cont.terminate<int>(),
          Cont.terminate<int>(),
          Cont.of(42),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });

    group('raceForLoserAll', () {
      test('returns last value to complete', () {
        final schedulers = List.generate(3, (_) => TestContScheduler());

        int? result;

        Cont.raceForLoserAll([
          Cont.of(1).subscribeOn(schedulers[0].asScheduler()),
          Cont.of(2).subscribeOn(schedulers[1].asScheduler()),
          Cont.of(3).subscribeOn(schedulers[2].asScheduler()),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        schedulers[0].flush();
        schedulers[1].flush();
        expect(result, isNull);

        schedulers[2].flush();
        expect(result, equals(3));
      });

      test('terminates with empty errors for empty list', () {
        List<ContError>? errors;

        Cont.raceForLoserAll<int>([]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors, isEmpty);
      });

      test('returns last successful value even if some fail', () {
        int? result;

        Cont.raceForLoserAll([
          Cont.of(1),
          Cont.terminate<int>(),
          Cont.of(3),
        ]).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, isNotNull);
      });

      test('terminates if all fail', () {
        List<ContError>? errors;

        Cont.raceForLoserAll([
          Cont.terminate<int>([ContError('e1', StackTrace.current)]),
          Cont.terminate<int>([ContError('e2', StackTrace.current)]),
        ]).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(2));
      });
    });

    group('subscribeOn', () {
      test('schedules subscription on provided scheduler', () {
        final testScheduler = TestContScheduler();

        int? result;

        Cont.of(42).subscribeOn(testScheduler.asScheduler()).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, isNull);

        testScheduler.flush();

        expect(result, equals(42));
      });
    });

    group('observeOn', () {
      test('schedules observation on provided scheduler', () {
        final testScheduler = TestContScheduler();

        int? result;

        Cont.of(42).observeOn(testScheduler.asScheduler()).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, isNull);

        testScheduler.flush();

        expect(result, equals(42));
      });

      test('schedules termination on provided scheduler', () {
        final testScheduler = TestContScheduler();

        List<ContError>? errors;

        Cont.terminate<int>([ContError('error', StackTrace.current)])
            .observeOn(testScheduler.asScheduler())
            .run(
              (e) => errors = e,
              (value) {},
            );

        expect(errors, isNull);

        testScheduler.flush();

        expect(errors, isNotNull);
      });
    });

    group('observeChannelOn', () {
      test('schedules value and termination on different schedulers', () {
        final valueScheduler = TestContScheduler();
        final terminateScheduler = TestContScheduler();

        int? result;

        Cont.of(42)
            .observeChannelOn(
              valueOn: valueScheduler.asScheduler(),
              terminateOn: terminateScheduler.asScheduler(),
            )
            .run(
              (errors) {},
              (value) => result = value,
            );

        expect(result, isNull);

        valueScheduler.flush();

        expect(result, equals(42));
      });

      test('schedules termination on terminateOn scheduler', () {
        final valueScheduler = TestContScheduler();
        final terminateScheduler = TestContScheduler();

        List<ContError>? errors;

        Cont.terminate<int>([ContError('error', StackTrace.current)])
            .observeChannelOn(
              valueOn: valueScheduler.asScheduler(),
              terminateOn: terminateScheduler.asScheduler(),
            )
            .run(
              (e) => errors = e,
              (value) {},
            );

        expect(errors, isNull);

        valueScheduler.flush();
        expect(errors, isNull);

        terminateScheduler.flush();
        expect(errors, isNotNull);
      });

      test('defaults to immediate scheduler', () {
        int? result;

        Cont.of(42).observeChannelOn().run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });

    group('withRef', () {
      test('provides mutable reference', () {
        int? result;

        Cont.withRef<int, int>(
          0,
          (ref) => ref.commit((before) => Cont.of((after) => (after + 10, after + 10))),
          (ref) => Cont.of(()),
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(10));
      });

      test('calls release on success', () {
        var releaseCalled = false;

        Cont.withRef<int, int>(
          0,
          (ref) => Cont.of(42),
          (ref) {
            releaseCalled = true;
            return Cont.of(());
          },
        ).run(
          (errors) {},
          (value) {},
        );

        expect(releaseCalled, isTrue);
      });

      test('calls release on failure', () {
        var releaseCalled = false;

        Cont.withRef<int, int>(
          0,
          (ref) => Cont.terminate([ContError('use error', StackTrace.current)]),
          (ref) {
            releaseCalled = true;
            return Cont.of(());
          },
        ).run(
          (errors) {},
          (value) {},
        );

        expect(releaseCalled, isTrue);
      });

      test('accumulates errors from use and release', () {
        List<ContError>? errors;

        Cont.withRef<int, int>(
          0,
          (ref) => Cont.terminate([ContError('use error', StackTrace.current)]),
          (ref) => Cont.terminate([ContError('release error', StackTrace.current)]),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        // Errors accumulate through orElseWith chain: [use, use, release, release]
        expect(errors!.length, greaterThanOrEqualTo(2));
        expect(errors!.any((e) => e.error == 'use error'), isTrue);
        expect(errors!.any((e) => e.error == 'release error'), isTrue);
      });

      test('catches exception in use function', () {
        List<ContError>? errors;

        Cont.withRef<int, int>(
          0,
          (ref) => throw Exception('use exception'),
          (ref) => Cont.of(()),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });

      test('catches exception in release function', () {
        List<ContError>? errors;

        Cont.withRef<int, int>(
          0,
          (ref) => Cont.of(42),
          (ref) => throw Exception('release exception'),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        expect(errors!.length, equals(1));
      });
    });

    group('Ref.commit', () {
      test('provides before and after state', () {
        int? beforeState;
        int? afterState;

        Cont.withRef<int, int>(
          10,
          (ref) {
            return ref.commit((before) {
              beforeState = before;
              return Cont.of((after) {
                afterState = after;
                return (after + 5, after + 5);
              });
            });
          },
          (ref) => Cont.of(()),
        ).run(
          (errors) {},
          (value) {},
        );

        expect(beforeState, equals(10));
        expect(afterState, equals(10));
      });

      test('updates state atomically', () {
        int? result;

        Cont.withRef<int, int>(
          0,
          (ref) {
            return ref
                .commit((before) => Cont.of((after) => (after + 10, after + 10)))
                .flatMap((v) {
              return ref.commit((before) => Cont.of((after) => (after + 5, after + 5)));
            });
          },
          (ref) => Cont.of(()),
        ).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(15));
      });

      test('propagates termination from inner cont', () {
        var terminateCalled = false;

        Cont.withRef<int, int>(
          0,
          (ref) {
            return ref.commit<int>((before) {
              return Cont.terminate([ContError('commit error', StackTrace.current)]);
            });
          },
          (ref) => Cont.of(()),
        ).run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });

      test('catches exception in commit function', () {
        List<ContError>? errors;

        Cont.withRef<int, int>(
          0,
          (ref) {
            return ref.commit<int>((before) {
              return Cont.of((after) {
                throw Exception('commit exception');
              });
            });
          },
          (ref) => Cont.of(()),
        ).run(
          (e) => errors = e,
          (value) {},
        );

        expect(errors, isNotNull);
        // Error is accumulated through the withRef error handling chain
        expect(errors!.length, greaterThanOrEqualTo(1));
        expect(errors!.any((e) => e.error.toString().contains('commit exception')), isTrue);
      });
    });

    group('flatten extension', () {
      test('flattens nested Cont', () {
        int? result;

        Cont.of(Cont.of(42)).flatten().run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });

      test('propagates outer termination', () {
        var terminateCalled = false;

        Cont.terminate<Cont<int>>().flatten().run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });

      test('propagates inner termination', () {
        var terminateCalled = false;

        Cont.of(Cont.terminate<int>()).flatten().run(
          (errors) => terminateCalled = true,
          (value) {},
        );

        expect(terminateCalled, isTrue);
      });
    });

    group('runWith', () {
      test('executes with observer', () {
        int? result;

        Cont.of(42).runWith(
          ContObserver(
            (errors) {},
            (value) => result = value,
          ),
        );

        expect(result, equals(42));
      });
    });

    group('run', () {
      test('executes with separate callbacks', () {
        int? result;

        Cont.of(42).run(
          (errors) {},
          (value) => result = value,
        );

        expect(result, equals(42));
      });
    });
  });
}
