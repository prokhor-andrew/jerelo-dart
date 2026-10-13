part of '../cont.dart';

Cont<E, F, List<A>> _allSequence<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((env, observer) {
    list = list.toList(); // defensive copy again
    _seq<F, A>(
      total: list.length,
      onRun: (
        index,
        updateCrash,
        updatePrimary,
        updateSecondary,
      ) {
        final Cont<E, F, A> cont = list[index];
        cont.runWith(
          env,
          observer.copyUpdate(
            onCrash: (crash) {
              updateCrash(crash);
            },
            onElse: (error) {
              updateSecondary(error);
            },
            onThen: (a) {
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
  return Cont.fromRun((env, observer) {
    list = list.toList(); // defensive copy again
    _seq<A, F>(
      total: list.length,
      onRun: (
        index,
        updateCrash,
        updatePrimary,
        updateSecondary,
      ) {
        final Cont<E, F, A> cont = list[index];
        cont.runWith(
          env,
          observer.copyUpdate(onCrash: (crash) {
            updateCrash(crash);
          }, onElse: (error) {
            updatePrimary(error);
          }, onThen: (a) {
            updateSecondary(a);
          }),
        );
      },
      onPrimary: observer.onElse,
      onSecondary: observer.onThen,
      onCrash: observer.onCrash,
    );
  });
}

Cont<E, F, A> _convergeSequence<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((env, observer) {
    list = list.toList(); // defensive copy

    if (list.isEmpty) {
      observer.onCrash(CollectedCrash._({}));
      return;
    }

    final crashes = <int, ContCrash>{};

    _stackSafeLoop<_Triple<int, A, F>, int,
        _Triple<(), A, F>>(
      seed: _Value1(0),
      keepRunningIf: (state) {
        switch (state) {
          case _Value1(a: final i):
            if (i >= list.length) {
              return _StackSafeLoopPolicyStop(_Value1(()));
            }
            return _StackSafeLoopPolicyKeepRunning(i);
          case _Value2(b: final a):
            return _StackSafeLoopPolicyStop(_Value2(a));
          case _Value3(c: final f):
            return _StackSafeLoopPolicyStop(_Value3(f));
        }
      },
      computation: (i, update) {
        ContCrash.tryCatch(() {
          list[i].runWith(
            env,
            observer.copyUpdate(
              onCrash: (c) {
                crashes[i] = c;
                update(_Value1(i + 1));
              },
              onElse: (f) {
                update(_Value3(f));
              },
              onThen: (a) {
                update(_Value2(a));
              },
            ),
          );
        })._ifCrash((crash) {
          crashes[i] = crash;
          update(_Value1(i + 1));
        });
      },
      escape: (finalState) {
        switch (finalState) {
          case _Value1():
            observer.onCrash(
              CollectedCrash._(Map.from(crashes)),
            );
          case _Value2(b: final a):
            observer.onThen(a);
          case _Value3(c: final f):
            observer.onElse(f);
        }
      },
    );
  });
}

void _seq<S, A>({
  required int total,
  required void Function(
    int index,
    void Function(ContCrash crash) updateCrash,
    void Function(A) updatePrimary,
    void Function(S) updateSecondary,
  ) onRun,
  required void Function(List<A> values) onPrimary,
  required void Function(S secondary) onSecondary,
  required void Function(ContCrash crash) onCrash,
}) {
  _stackSafeLoop<
      _Triple<List<A>, S, ContCrash>, // state
      List<A>, // loop input
      _Triple<List<A>, S, ContCrash> // loop output
      >(
    seed: _Value1([]),
    keepRunningIf: (state) {
      switch (state) {
        case _Value1(a: final values):
          if (values.length >= total) {
            return _StackSafeLoopPolicyStop(
              _Value1(values),
            );
          }
          return _StackSafeLoopPolicyKeepRunning(values);
        case _Value2(b: final secondary):
          return _StackSafeLoopPolicyStop(
            _Value2(secondary),
          );
        case _Value3(c: final crash):
          return _StackSafeLoopPolicyStop(_Value3(crash));
      }
    },
    computation: (values, update) {
      final i = values.length;
      ContCrash.tryCatch(() {
        onRun(
          i,
          (crash) {
            update(_Value3(crash));
          },
          (a) {
            values.add(a);
            update(_Value1(values));
          },
          (secondary) {
            update(_Value2(secondary));
          },
        );
      })._ifCrash((crash) {
        update(_Value3(crash));
      });
    },
    escape: (triple) {
      switch (triple) {
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
