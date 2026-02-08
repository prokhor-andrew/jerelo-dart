import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromRun', () {
    test('Cont.fromRun with ContObserver<Never>', () {
      final cont = Cont.fromRun<(), Never>((
        runtime,
        observer,
      ) {
        observer.onTerminate();
      });

      cont.run(
        (),
        (errors) {
          expect(errors, []);
        },
        (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.fromRun is run properly', () {
      var isRun = false;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        isRun = true;
      });

      expect(isRun, false);
      cont.run((), (_) {}, (_) {});
      expect(isRun, true);
    });

    test('Cont.fromRun onValue channel used', () {
      var value = 15;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onValue(0);
      });

      expect(value, 15);
      cont.run((), (_) {}, (v) => value = v);
      expect(value, 0);
    });

    test(
      'Cont.fromRun onTerminate empty channel used manually',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([]);
        });

        expect(errors, null);
        cont.run((), (e) => errors = e, (_) {});
        expect(errors, []);
      },
    );

    test(
      'Cont.fromRun onTerminate error channel used manually',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([
            ContError("random error", StackTrace.current),
          ]);
        });

        expect(errors, null);
        cont.run((), (e) => errors = e, (_) {});

        expect(errors![0].error, "random error");
      },
    );

    test(
      'Cont.fromRun onTerminate error channel used when throws',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          throw "random error";
        });

        expect(errors, null);
        cont.run((), (e) => errors = e, (_) {});

        expect(errors![0].error, "random error");
      },
    );

    test('Cont.fromRun onValue idempotent', () {
      var value = 0;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onValue(15);
        observer.onValue(20);
      });

      expect(value, 0);
      cont.run((), (_) {}, (v) => value = v);
      expect(value, 15);
    });

    test('Cont.fromRun onTerminate idempotent', () {
      List<ContError>? errors = null;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onTerminate([
          ContError("random error", StackTrace.current),
        ]);
        observer.onTerminate([
          ContError("random error2", StackTrace.current),
        ]);
      });

      expect(errors, null);
      cont.run((), (e) => errors = e, (_) {});

      expect(errors![0].error, 'random error');
    });

    test(
      'Cont.fromRun onValue and onTerminate share idempotency',
      () {
        var value = 0;
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onValue(15);
          observer.onTerminate([
            ContError("random error", StackTrace.current),
          ]);
        });

        expect(errors, null);
        expect(value, 0);

        cont.run((), (e) => errors = e, (v) => value = v);

        expect(errors, null);
        expect(value, 15);
      },
    );

    test(
      'Cont.fromRun onTerminate and onValue share idempotency',
      () {
        var value = 0;
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([
            ContError("random error", StackTrace.current),
          ]);
          observer.onValue(15);
        });

        expect(errors, null);
        expect(value, 0);

        cont.run((), (e) => errors = e, (v) => value = v);

        expect(value, 0);
        expect(errors![0].error, 'random error');
      },
    );

    test('Cont.fromRun env passed properly', () {
      final cont = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        expect(runtime.env(), 15);
      });

      cont.run(15, (_) {}, (_) {});
    });


    test('Cont.fromRun errors defensive copy', () {
      final errors0 = [0, 1, 2, 3]
          .map(
            (value) => ContError(value, StackTrace.current),
          )
          .toList();
      List<ContError>? errors1 = null;

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onTerminate(errors0);
      });

      expect(errors0.map((error) => error.error).toList(), [
        0,
        1,
        2,
        3,
      ]);
      expect(errors1, null);

      cont.run((), (errors) {
        errors.add(ContError(4, StackTrace.current));
        errors1 = errors;
      }, (value) {});

      expect(errors0.map((error) => error.error).toList(), [
        0,
        1,
        2,
        3,
      ]);
      expect(
        errors1!.map((error) => error.error).toList(),
        [0, 1, 2, 3, 4],
      );
    });
  });
}
