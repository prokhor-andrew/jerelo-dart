import 'package:jerelo/jerelo.dart';

void main() {
  Cont.of(5).flatMap((value) {
    return Cont.fromThunk(() {
      return value + 1;
    });
  }).execute(onSome: print);
}
