part of '../cont.dart';

// The run loop and the Cont cases it interprets.
//
// The loop works with erased values (Object?): it never reads a field
// whose type mentions a type parameter in a contravariant position,
// because Dart would check such a read against the static type
// arguments, and a Cont used through a wider type would fail it. Each
// case does its typed work in its own methods instead, where its type
// arguments are exact, and casts the erased value it receives.

/// A computation run by a function: everything [Cont.fromRun] builds.
final class _LeafCont<E, F, A> extends Cont<E, F, A> {
  // The callbacks are passed as plain function types rather than as a
  // ContObserver<F, A>. Dart treats class type parameters as covariant,
  // but checks function types soundly, so this keeps Cont safely
  // covariant in F and A: a Cont<E, String, int> can be used as a
  // Cont<E, Object?, int>.
  final void Function(
    ContRuntime<E> runtime,
    void Function(NormalCrash crash) onPanic,
    void Function(ContCrash crash) onCrash,
    void Function(F error) onElse,
    void Function(A value) onThen,
  ) _run;

  const _LeafCont._(this._run) : super._();

  void _start(
    ContRuntime<Object?> runtime,
    void Function(NormalCrash crash) onPanic,
    void Function(ContCrash crash) onCrash,
    void Function(Object? error) onElse,
    void Function(Object? value) onThen,
  ) {
    _run(
      runtime as ContRuntime<E>,
      onPanic,
      onCrash,
      onElse,
      onThen,
    );
  }
}

/// `source.thenDo(f)`.
final class _ThenDoCont<E, F, A, A2>
    extends Cont<E, F, A2> {
  final Cont<E, F, A> _source;
  final Cont<E, F, A2> Function(A value) _f;

  const _ThenDoCont(this._source, this._f) : super._();

  Cont<Object?, Object?, Object?> _apply(Object? value) {
    return _f(value as A);
  }
}

/// `source.elseDo(f)`.
final class _ElseDoCont<E, F, F2, A>
    extends Cont<E, F2, A> {
  final Cont<E, F, A> _source;
  final Cont<E, F2, A> Function(F error) _f;

  const _ElseDoCont(this._source, this._f) : super._();

  Cont<Object?, Object?, Object?> _apply(Object? error) {
    return _f(error as F);
  }
}

/// `source.crashDo(f)`.
final class _CrashDoCont<E, F, A> extends Cont<E, F, A> {
  final Cont<E, F, A> _source;
  final Cont<E, F, A> Function(ContCrash crash) _f;

  const _CrashDoCont(this._source, this._f) : super._();

  Cont<Object?, Object?, Object?> _apply(ContCrash crash) {
    return _f(crash);
  }
}

/// `Cont.fromDeferred(thunk)`.
final class _DeferCont<E, F, A> extends Cont<E, F, A> {
  final Cont<E, F, A> Function() _thunk;

  const _DeferCont(this._thunk) : super._();

  Cont<Object?, Object?, Object?> _build() {
    return _thunk();
  }
}

/// `source.local(f)`.
final class _LocalCont<E2, E, F, A> extends Cont<E2, F, A> {
  final Cont<E, F, A> _source;
  final E Function(E2 env) _f;

  const _LocalCont(this._source, this._f) : super._();

  ContRuntime<Object?> _mapRuntime(
    ContRuntime<Object?> runtime,
  ) {
    return runtime.copyUpdateEnv<E>(
      _f(runtime.env() as E2),
    );
  }
}

/// Restores the runtime once the source of a [_LocalCont] has an
/// outcome.
final class _RuntimeFrame {
  final ContRuntime<Object?> runtime;

  const _RuntimeFrame(this.runtime);
}

const int _thenOutcome = 0;
const int _elseOutcome = 1;
const int _crashOutcome = 2;

/// Runs one [Cont] once.
///
/// A node pushes itself onto [_frames] as the handler of its channel
/// and continues with its source. A leaf is started; when it reports
/// while starting, the loop continues in place, and when it reports
/// later, its callback resumes the loop with the same frames. An
/// outcome pops frames until one handles its channel, and the
/// computation that frame returns runs next. With no frame left, the
/// outcome goes to the callbacks.
///
/// Cancellation is checked as the operators did before: once the
/// runtime is cancelled, no node starts and no frame function runs, and
/// the computation stops without an outcome.
///
/// The frames live in the run, never in the [Cont], so a [Cont] can be
/// run any number of times, also concurrently.
final class _RunLoop {
  ContRuntime<Object?> _runtime;
  final void Function(NormalCrash crash) _onUnsafePanic;
  final void Function(ContCrash crash) _onCrash;
  final void Function(Object? error) _onElse;
  final void Function(Object? value) _onThen;

  // _ThenDoCont, _ElseDoCont and _CrashDoCont waiting for an outcome,
  // and _RuntimeFrames
  final List<Object> _frames = [];

  // the outcome being delivered
  int _kind = _thenOutcome;
  Object? _value;

  bool _isDone = false;

  // the leaf that is running, if any: reports of older leaves are
  // ignored, and a report while it starts continues the loop in place
  int _leafGeneration = 0;
  bool _isStarting = false;
  bool _hasReportedWhileStarting = false;

  _RunLoop(
    this._runtime,
    this._onUnsafePanic,
    this._onCrash,
    this._onElse,
    this._onThen,
  );

  void start(Cont<Object?, Object?, Object?> cont) {
    _loop(cont);
  }

  void _report(int generation, int kind, Object? value) {
    if (_isDone || generation != _leafGeneration) {
      return;
    }
    _kind = kind;
    _value = value;
    if (_isStarting) {
      _hasReportedWhileStarting = true;
      return;
    }
    // reported after starting: resume with the frames left
    _loop(null);
  }

  // Runs until a leaf is still running, the outcome is delivered or the
  // run is cancelled. A null [current] delivers the outcome in _kind
  // and _value.
  void _loop(Cont<Object?, Object?, Object?>? current) {
    while (true) {
      if (current == null) {
        current = _unwind();
        if (current == null) {
          return;
        }
      }

      if (_runtime.isCancelled()) {
        return; // stop without an outcome
      }

      switch (current) {
        case _ThenDoCont():
          _frames.add(current);
          current = current._source;
        case _ElseDoCont():
          _frames.add(current);
          current = current._source;
        case _CrashDoCont():
          _frames.add(current);
          current = current._source;
        case _DeferCont():
          final deferred = current;
          current = ContCrash.tryCatch(deferred._build)
              .match<Cont<Object?, Object?, Object?>?>(
            (cont) {
              return cont;
            },
            (crash) {
              // a throw from thunk is a crash
              _kind = _crashOutcome;
              _value = crash;
              return null;
            },
          );
        case _LocalCont():
          final local = current;
          final runtime = _runtime;
          current = ContCrash.tryCatch(() {
            return local._mapRuntime(runtime);
          }).match<Cont<Object?, Object?, Object?>?>(
            (innerRuntime) {
              _frames.add(_RuntimeFrame(runtime));
              _runtime = innerRuntime;
              return local._source;
            },
            (crash) {
              // a throw from f is a crash
              _kind = _crashOutcome;
              _value = crash;
              return null;
            },
          );
        case _LeafCont():
          if (!_startLeaf(current)) {
            return; // the leaf reports later and resumes the loop
          }
          current = null;
      }
    }
  }

  // Starts [leaf]. Returns true when it reported while starting.
  bool _startLeaf(
      _LeafCont<Object?, Object?, Object?> leaf) {
    final generation = ++_leafGeneration;
    _isStarting = true;
    _hasReportedWhileStarting = false;

    ContCrash.tryCatch(() {
      leaf._start(
        _runtime,
        _onUnsafePanic,
        (crash) {
          _report(generation, _crashOutcome, crash);
        },
        (error) {
          _report(generation, _elseOutcome, error);
        },
        (value) {
          _report(generation, _thenOutcome, value);
        },
      );
    }).match((_) {}, (crash) {
      // the leaf could not start, for example because the environment
      // is not of its type
      if (!_hasReportedWhileStarting) {
        _kind = _crashOutcome;
        _value = crash;
        _hasReportedWhileStarting = true;
      }
    });
    _isStarting = false;

    return _hasReportedWhileStarting;
  }

  // Pops frames until one handles the outcome in _kind and _value, and
  // returns the computation it builds. Returns null once the outcome
  // went to the callbacks, or when the run was cancelled.
  Cont<Object?, Object?, Object?>? _unwind() {
    while (_frames.isNotEmpty) {
      final frame = _frames.removeLast();
      final Cont<Object?, Object?, Object?> Function() next;
      switch (frame) {
        case _RuntimeFrame(runtime: final runtime):
          _runtime = runtime;
          continue;
        case _ThenDoCont() when _kind == _thenOutcome:
          final value = _value;
          next = () {
            return frame._apply(value);
          };
        case _ElseDoCont() when _kind == _elseOutcome:
          final error = _value;
          next = () {
            return frame._apply(error);
          };
        case _CrashDoCont() when _kind == _crashOutcome:
          final crash = _value as ContCrash;
          next = () {
            return frame._apply(crash);
          };
        default:
          continue; // the frame handles another channel
      }

      if (_runtime.isCancelled()) {
        return null; // stop without an outcome
      }

      final cont = ContCrash.tryCatch(next).match(
        (cont) {
          return cont;
        },
        (crash) {
          // a throw from f is a crash
          _kind = _crashOutcome;
          _value = crash;
          return null;
        },
      );
      if (cont != null) {
        return cont;
      }
    }

    _finish();
    return null;
  }

  void _finish() {
    if (_isDone) {
      return;
    }
    _isDone = true;
    final kind = _kind;
    final value = _value;
    ContCrash.tryCatch(() {
      switch (kind) {
        case _thenOutcome:
          _onThen(value);
        case _elseOutcome:
          _onElse(value);
        default:
          _onCrash(value as ContCrash);
      }
    }).match((_) {}, (panic) {
      // a throw from a callback is a panic; if onPanic throws too, its
      // error is rethrown, as in fromRun
      ContCrash.tryCatch(() {
        _onUnsafePanic(panic);
      }).match((_) {}, _panic);
    });
  }
}
