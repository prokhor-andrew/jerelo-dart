import 'package:jerelo/jerelo.dart';
import 'package:jerelo/src/cont_error.dart';

void main() {
  Cont.withActor<int>((actor) {
    print('start');

    // Consumer starts immediately → will PARK
    actor
        .dequeue()
        .doOnSome((v) {
          print('consumer got $v');
        })
        .run(onFatal: (_, __) {}, onNone: () {}, onFail: (_, __) {}, onSome: (_) {});

    // Producer starts AFTER delay
    Cont.fromRun<()>((obs) {
      Future.delayed(const Duration(seconds: 2), () {
        print('enqueueing...');
        actor.enqueue(42).subscribe(obs);
      });
    }).run(onFatal: (_, __) {}, onNone: () {}, onFail: (_, __) {}, onSome: (_) {});

    return Cont.empty();
  }).run(onFatal: (_, _) {});
}
