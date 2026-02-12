import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.bracket', () {
    test('acquires, uses, and releases', () {
      final order = <String>[];
      String? value;

      Cont.bracket<(), String, String>(
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
      List<ContError>? errors;

      Cont.bracket<(), String, int>(
        acquire: Cont.of('resource'),
        release: (resource) {
          order.add('release');
          return Cont.of(());
        },
        use: (resource) {
          order.add('use');
          return Cont.stop<(), int>([
            ContError.capture('use error'),
          ]);
        },
      ).run((), onElse: (e) => errors = e);

      expect(order, ['use', 'release']);
      expect(errors!.length, 1);
      expect(errors![0].error, 'use error');
    });

    test('terminates on acquire failure', () {
      bool useCalled = false;
      bool releaseCalled = false;
      List<ContError>? errors;

      Cont.bracket<(), String, int>(
        acquire: Cont.stop([
          ContError.capture('acquire error'),
        ]),
        release: (resource) {
          releaseCalled = true;
          return Cont.of(());
        },
        use: (resource) {
          useCalled = true;
          return Cont.of(42);
        },
      ).run((), onElse: (e) => errors = e);

      expect(useCalled, false);
      expect(releaseCalled, false);
      expect(errors!.length, 1);
      expect(errors![0].error, 'acquire error');
    });

    test(
      'combines errors when use and release both fail',
      () {
        List<ContError>? errors;

        Cont.bracket<(), String, int>(
          acquire: Cont.of('resource'),
          release: (resource) {
            return Cont.stop<(), ()>([
              ContError.capture('release error'),
            ]);
          },
          use: (resource) {
            return Cont.stop<(), int>([
              ContError.capture('use error'),
            ]);
          },
        ).run((), onElse: (e) => errors = e);

        expect(errors!.length, 2);
        expect(errors![0].error, 'use error');
        expect(errors![1].error, 'release error');
      },
    );

    test(
      'terminates with release errors when use succeeds but release fails',
      () {
        List<ContError>? errors;

        Cont.bracket<(), String, int>(
          acquire: Cont.of('resource'),
          release: (resource) {
            return Cont.stop<(), ()>([
              ContError.capture('release error'),
            ]);
          },
          use: (resource) {
            return Cont.of(42);
          },
        ).run((), onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'release error');
      },
    );

    test('supports multiple runs', () {
      var acquireCount = 0;
      var useCount = 0;
      var releaseCount = 0;

      final cont = Cont.bracket<(), String, int>(
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

      Cont.bracket<(), String, int>(
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
