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
  //
  // _run returns the canceller of the computation it starts.
  final void Function() Function(
    E env,
    void Function(NormalCrash crash) onPanic,
    void Function(ContCrash crash) onCrash,
    void Function(F error) onElse,
    void Function(A value) onThen,
  ) _run;

  const _LeafCont._(this._run) : super._();

  void Function() _start(
    Object? env,
    void Function(NormalCrash crash) onPanic,
    void Function(ContCrash crash) onCrash,
    void Function(Object? error) onElse,
    void Function(Object? value) onThen,
  ) {
    return _run(env as E, onPanic, onCrash, onElse, onThen);
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
/// The frames live in the run, never in the [Cont], so a [Cont] can be
/// run any number of times, also concurrently.
final class _RunLoop {
  Object? _env;
  final void Function(NormalCrash crash) _onUnsafePanic;
  final void Function(ContCrash crash) _onCrash;
  final void Function(Object? error) _onElse;
  final void Function(Object? value) _onThen;

  // _ThenDoCont, _ElseDoCont and _CrashDoCont waiting for an outcome
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

  // cancelling cancels the running leaf, and every leaf that starts
  // afterwards as soon as it starts
  bool _isCancelled = false;
  void Function() _leafCanceller = _voidIgnore;

  _RunLoop(
    this._env,
    this._onUnsafePanic,
    this._onCrash,
    this._onElse,
    this._onThen,
  );

  /// Runs [cont] and returns the canceller of the run.
  void Function() start(
      Cont<Object?, Object?, Object?> cont) {
    _loop(cont);
    return _cancel;
  }

  void _cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final canceller = _leafCanceller;
    _leafCanceller = _voidIgnore;
    canceller();
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
    _leafCanceller = _voidIgnore;
    _loop(null);
  }

  // Runs until a leaf is still running or the outcome is delivered. A
  // null [current] delivers the outcome in _kind and _value.
  void _loop(Cont<Object?, Object?, Object?>? current) {
    while (true) {
      if (current == null) {
        current = _unwind();
        if (current == null) {
          return;
        }
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

    void Function() canceller = _voidIgnore;
    final result = ContCrash.tryCatch(() {
      canceller = leaf._start(
        _env,
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
    });
    if (result case CrashCrashOr(crash: final crash)) {
      // the leaf could not start, for example because the environment
      // is not of its type
      if (_hasReportedWhileStarting) {
        _panicSafely(crash);
      } else {
        _kind = _crashOutcome;
        _value = crash;
        _hasReportedWhileStarting = true;
      }
    }

    // a leaf started after a cancel is cancelled at once; reporting
    // from its canceller still counts as reporting while starting
    if (_isCancelled && !_hasReportedWhileStarting) {
      canceller();
    }
    _isStarting = false;

    if (_hasReportedWhileStarting) {
      return true;
    }
    _leafCanceller = canceller;
    return false;
  }

  // Pops frames until one handles the outcome in _kind and _value, and
  // returns the computation it builds. Returns null once the outcome
  // went to the callbacks.
  Cont<Object?, Object?, Object?>? _unwind() {
    while (_frames.isNotEmpty) {
      final frame = _frames.removeLast();
      final CrashOr<Cont<Object?, Object?, Object?>> next;
      switch (frame) {
        case _ThenDoCont() when _kind == _thenOutcome:
          final value = _value;
          next = ContCrash.tryCatch(() {
            return frame._apply(value);
          });
        case _ElseDoCont() when _kind == _elseOutcome:
          final error = _value;
          next = ContCrash.tryCatch(() {
            return frame._apply(error);
          });
        case _CrashDoCont() when _kind == _crashOutcome:
          final crash = _value as ContCrash;
          next = ContCrash.tryCatch(() {
            return frame._apply(crash);
          });
        default:
          continue; // the frame handles another channel
      }
      switch (next) {
        case ValueCrashOr(value: final cont):
          return cont;
        case CrashCrashOr(crash: final crash):
          // a throw from f is a crash
          _kind = _crashOutcome;
          _value = crash;
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
    })._ifCrash(_panicSafely);
  }

  // a throw from a callback is a panic; if onPanic throws too, the
  // panic is rethrown, as in fromRun
  void _panicSafely(NormalCrash panic) {
    ContCrash.tryCatch(() {
      _onUnsafePanic(panic);
    })._ifCrash((_) {
      _panic(panic);
    });
  }
}
