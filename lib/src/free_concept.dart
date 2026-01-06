abstract class Effect<A> {
  const Effect();
}

sealed class Prog<A> {
  const Prog();

  Prog<B> map<B>(B Function(A) f) {
    return FlatMap<A, B>(this, (a) {
      return Of(f(a));
    });
  }

  Prog<B> flatMap<B>(Prog<B> Function(A) f) {
    return FlatMap<A, B>(this, f);
  }

  Prog<A> filter(bool Function(A) predicate) {
    return flatMap((a) {
      final isValid = predicate(a);
      if (isValid) {
        return Of(a);
      }

      return Empty();
    });
  }
}

final class Of<A> extends Prog<A> {
  final A value;

  const Of(this.value);
}

final class Empty<A> extends Prog<A> {
  const Empty();
}

final class Error<A> extends Prog<A> {
  final Object error;
  final List<Object> errors;

  const Error(this.error, [this.errors = const []]);
}

// TODO:
final class Perform<A> extends Prog<A> {
  final Effect<A> effect;

  const Perform(this.effect);
}

final class FlatMap<X, A> extends Prog<A> {
  final Prog<X> src;
  final Prog<A> Function(X) k;

  const FlatMap(this.src, this.k);
}

final class CatchEmpty<A> extends Prog<A> {
  final Prog<A> src;
  final Prog<A> Function() k;

  const CatchEmpty(this.src, this.k);
}

final class CatchError<A> extends Prog<A> {
  final Prog<A> src;
  final Prog<A> Function(Object error, List<Object> errors) k;

  const CatchError(this.src, this.k);
}

final class SeqBoth<A, B, C> extends Prog<C> {
  final Prog<A> left;
  final Prog<B> right;

  final C Function(A, B) f;

  const SeqBoth(this.left, this.right, this.f);
}

final class ParBoth<A, B, C> extends Prog<C> {
  final Prog<A> left;
  final Prog<B> right;
  final C Function(A, B) f;

  const ParBoth(this.left, this.right, this.f);
}

final class RaceFirst<A, B, C> extends Prog<C> {
  final Prog<A> left;
  final C Function(A) lf;

  final Prog<A> right;
  final C Function(B) rf;

  const RaceFirst(this.left, this.lf, this.right, this.rf);
}

final class RaceLast<A, B, C> extends Prog<C> {
  final Prog<A> left;
  final C Function(A) lf;

  final Prog<A> right;
  final C Function(B) rf;

  const RaceLast(this.left, this.lf, this.right, this.rf);
}

final class OrElse<A, B, C> extends Prog<C> {
  final Prog<A> left;
  final C Function(A) lf;

  final Prog<A> right;
  final C Function(B) rf;

  const OrElse(this.left, this.lf, this.right, this.rf);
}

// TODO: add race all first
// TODO: add race all last
// TODO: first success