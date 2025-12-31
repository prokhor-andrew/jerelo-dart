import 'package:jerelo/jerelo.dart';
import 'package:jerelo/src/cont_error.dart';

void main() {
  Cont.of(5)
      .flatMap((value) {
        return Cont.fromThunk(() {
          return value + 1;
        });
      })
      .run((_,_) {}, onSome: print);

  Cont.fromRun<int>((observer) {
    observer.onFail(ContError('error', StackTrace.current));
  });
}
