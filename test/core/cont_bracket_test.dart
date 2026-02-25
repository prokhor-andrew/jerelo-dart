import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.bracket', () {
    test('acquires, uses, and releases', () {
      final order = <String>[];
      String? value;

      Cont.bracket<String, (), String, String>(
        acquire: Cont.fromRun((runtime, observer) {
          order.add('acquire');
          observer.onThen('resource');
        }),
        release: (resource) {
          order.add('release: $resource');
          return Cont.of(());
        },
        use: (resource) {
          order.add('use: $resource');
          return Cont.of('result from $resource');
        },
      ).run((), onThen: (val) => value = val);

      expect(order, [
        'acquire',
        'use: resource',
        'release: resource',
      ]);
      expect(value, 'result from resource');
    });

    test('releases on use failure', () {
      final order = <String>[];
      String? error;

      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('resource'),
        release: (resource) {
          order.add('release');
          return Cont.of(());
        },
        use: (resource) {
          order.add('use');
          return Cont.error('use error');
        },
      ).run((), onElse: (e) => error = e);

      expect(order, ['use', 'release']);
      expect(error, 'use error');
    });

    test('crashes on acquire crash', () {
      bool useCalled = false;
      bool releaseCalled = false;
      ContCrash? crash;

      Cont.bracket<String, (), String, int>(
        acquire: Cont.fromRun<(), Never, String>((runtime, observer) {
          throw 'acquire error';
        }),
        release: (resource) {
          releaseCalled = true;
          return Cont.of(());
        },
        use: (resource) {
          useCalled = true;
          return Cont.of(42);
        },
      ).run((), onCrash: (c) => crash = c);

      expect(useCalled, false);
      expect(releaseCalled, false);
      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'acquire error');
    });

    test('supports multiple runs', () {
      var acquireCount = 0;
      var useCount = 0;
      var releaseCount = 0;

      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.fromRun((runtime, observer) {
          acquireCount++;
          observer.onThen('resource');
        }),
        release: (resource) {
          releaseCount++;
          return Cont.of(());
        },
        use: (resource) {
          useCount++;
          return Cont.of(42);
        },
      );

      cont.run(());
      expect(acquireCount, 1);
      expect(useCount, 1);
      expect(releaseCount, 1);

      cont.run(());
      expect(acquireCount, 2);
      expect(useCount, 2);
      expect(releaseCount, 2);
    });

    test('passes resource to both use and release', () {
      String? usedResource;
      String? releasedResource;

      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('my-resource'),
        release: (resource) {
          releasedResource = resource;
          return Cont.of(());
        },
        use: (resource) {
          usedResource = resource;
          return Cont.of(42);
        },
      ).run(());

      expect(usedResource, 'my-resource');
      expect(releasedResource, 'my-resource');
    });
  });
}
