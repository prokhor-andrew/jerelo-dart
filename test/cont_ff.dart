import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.ff', () {
    test('executes side effect', () {
      var executed = false;

      Cont.fromRun<(), ()>((runtime, observer) {
        executed = true;
        observer.onValue(());
      }).ff(());

      expect(executed, true);
    });

    test('ignores value', () {
      // ff returns void, not a cancel token
      Cont.of<(), int>(42).ff(());
    });

    test('ignores termination', () {
      Cont.terminate<(), int>([
        ContError.capture('err'),
      ]).ff(());
    });

    test('provides environment', () {
      String? receivedEnv;

      Cont.fromRun<String, ()>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onValue(());
      }).ff('hello');

      expect(receivedEnv, 'hello');
    });

    test('supports multiple runs', () {
      var callCount = 0;

      final cont = Cont.fromRun<(), ()>((runtime, observer) {
        callCount++;
        observer.onValue(());
      });

      cont.ff(());
      expect(callCount, 1);

      cont.ff(());
      expect(callCount, 2);
    });

    test('is never cancellable', () {
      // ff does not return a cancel token, so it cannot be cancelled
      var executed = false;

      Cont.fromRun<(), ()>((runtime, observer) {
        // isCancelled should always return false for ff
        expect(runtime.isCancelled(), false);
        executed = true;
        observer.onValue(());
      }).ff(());

      expect(executed, true);
    });
  });
}
