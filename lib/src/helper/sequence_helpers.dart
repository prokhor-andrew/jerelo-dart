part of '../cont.dart';

Cont<E, F, List<A>> _allSequence<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy again
    _seq<F, A>(
      total: list.length,
      onRun: (
        index,
        updateCancel,
        updateCrash,
        updatePrimary,
        updateSecondary,
      ) {
        final Cont<E, F, A> cont = list[index].absurdify();
        cont.runWith(
          runtime,
          observer.copyUpdateOnCrash((crash) {
            if (runtime.isCancelled()) {
              updateCancel();
              return;
            }
            updateCrash(crash);
          }).copyUpdateOnElse<F>((error) {
            if (runtime.isCancelled()) {
              updateCancel();
              return;
            }
            updateSecondary(error);
          }).copyUpdateOnThen<A>(
            (a) {
              if (runtime.isCancelled()) {
                updateCancel();
                return;
              }
              updatePrimary(a);
            },
          ),
        );
      },
      onPrimary: observer.onThen,
      onSecondary: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}

Cont<E, List<F>, A> _anySequence<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy again
    _seq<A, F>(
      total: list.length,
      onRun: (
        index,
        updateCancel,
        updateCrash,
        updatePrimary,
        updateSecondary,
      ) {
        final Cont<E, F, A> cont = list[index].absurdify();
        cont.runWith(
          runtime,
          observer.copyUpdateOnCrash((crash) {
            if (runtime.isCancelled()) {
              updateCancel();
              return;
            }
            updateCrash(crash);
          }).copyUpdateOnElse<F>((error) {
            if (runtime.isCancelled()) {
              updateCancel();
              return;
            }
            updatePrimary(error);
          }).copyUpdateOnThen<A>(
            (a) {
              if (runtime.isCancelled()) {
                updateCancel();
                return;
              }
              updateSecondary(a);
            },
          ),
        );
      },
      onPrimary: observer.onElse,
      onSecondary: observer.onThen,
      onCrash: observer.onCrash,
    );
  });
}

void _seq<S, A>({
  required int total,
  required void Function(
    int index,
    void Function() updateCancel,
    void Function(ContCrash crash) updateCrash,
    void Function(A) updatePrimary,
    void Function(S) updateSecondary,
  ) onRun,
  required void Function(List<A> values) onPrimary,
  required void Function(S secondary) onSecondary,
  required void Function(ContCrash crash) onCrash,
}) {
  _stackSafeLoop<
      _Triple<List<A>, S, ContCrash>?, // state
      List<A>, // loop input
      _Triple<List<A>, S, ContCrash>? // loop output
      >(
    seed: _Value1([]),
    keepRunningIf: (state) {
      switch (state) {
        case null:
          return _StackSafeLoopPolicyStop(null);
        case _Value1(a: final values):
          if (values.length >= total) {
            return _StackSafeLoopPolicyStop(
              _Value1(values),
            );
          }
          return _StackSafeLoopPolicyKeepRunning(values);
        case _Value2(b: final f):
          return _StackSafeLoopPolicyStop(_Value2(f));
        case _Value3(c: final error):
          return _StackSafeLoopPolicyStop(_Value3(error));
      }
    },
    computation: (values, update) {
      final i = values.length;
      final crash = ContCrash.tryCatch(() {
        onRun(
          i,
          () {
            update(null);
          },
          (crash) {
            update(
              _Value3(crash),
            );
          },
          (a) {
            values.add(a);
            update(
              _Value1(values),
            );
          },
          (f) {
            update(_Value2(f));
          },
        );
      });

      if (crash != null) {
        update(
          _Value3(crash),
        );
      }
    },
    escape: (triple) {
      switch (triple) {
        case null:
          // cancellation
          return;
        case _Value1(a: final values):
          onPrimary(values.toList()); // defensive copy
        case _Value2(b: final secondary):
          onSecondary(secondary);
        case _Value3(c: final crash):
          onCrash(crash);
      }
    },
  );
}
