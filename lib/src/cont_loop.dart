sealed class ContLoop<S, A> {
  const ContLoop();
}

final class Continue<S, A> extends ContLoop<S, A> {
  final S state;
  const Continue(this.state);
}

final class Done<S, A> extends ContLoop<S, A> {
  final A value;
  const Done(this.value);
}