import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.bracket', () {
    test('acquires, uses, and releases', () {
      final log = <String>[];

      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.fromRun((runtime, observer) {
          log.add('acquire');
          observer.onThen('resource');
        }),
        release: (r) => Cont.fromRun((runtime, observer) {
          log.add('release:$r');
          observer.onThen(());
        }),
        use: (r) => Cont.fromRun((runtime, observer) {
          log.add('use:$r');
          observer.onThen(42);
        }),
      );

      int? result;
      cont.run((), onThen: (v) => result = v);

      expect(
          log,
          equals([
            'acquire',
            'use:resource',
            'release:resource'
          ]));
      expect(result, equals(42));
    });

    test('releases on use failure', () {
      final log = <String>[];

      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.fromRun((runtime, observer) {
          log.add('acquire');
          observer.onThen('resource');
        }),
        release: (r) => Cont.fromRun((runtime, observer) {
          log.add('release');
          observer.onThen(());
        }),
        use: (r) => Cont.fromRun((runtime, observer) {
          log.add('use');
          observer.onElse('error');
        }),
      );

      String? error;
      cont.run((), onElse: (e) => error = e);

      expect(log, equals(['acquire', 'use', 'release']));
      expect(error, equals('error'));
    });

    test('crashes on acquire crash', () {
      bool crashCalled = false;

      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.fromRun((runtime, observer) {
          throw Exception('acquire crashed');
        }),
        release: (r) => Cont.of(()),
        use: (r) => Cont.of(42),
      );

      cont.run(
        (),
        onCrash: (_) => crashCalled = true,
        onPanic: (_) {},
      );

      expect(crashCalled, isTrue);
    });

    test('supports multiple runs', () {
      int releaseCount = 0;

      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.of('resource'),
        release: (r) => Cont.fromRun((runtime, observer) {
          releaseCount++;
          observer.onThen(());
        }),
        use: (r) => Cont.of(42),
      );

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
      expect(releaseCount, equals(2));
    });

    test('passes resource to both use and release', () {
      final capturedInUse = <String>[];
      final capturedInRelease = <String>[];
      final resource = 'my-resource';

      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.of(resource),
        release: (r) => Cont.fromRun((runtime, observer) {
          capturedInRelease.add(r);
          observer.onThen(());
        }),
        use: (r) => Cont.fromRun((runtime, observer) {
          capturedInUse.add(r);
          observer.onThen(1);
        }),
      );

      cont.run(());

      expect(capturedInUse, equals([resource]));
      expect(capturedInRelease, equals([resource]));
    });
  });
}
