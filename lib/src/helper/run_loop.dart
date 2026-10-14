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
final class _LeafCont<E, A> extends Cont<E, A> {
  // The callbacks are passed as plain function types rather than as a
  // ContObserver<A>. Dart treats class type parameters as covariant,
  // but checks function types soundly, so this keeps Cont safely
  // covariant in A: a Cont<E, int> can be used as a Cont<E, Object?>.
  final void Function(
    ContRuntime<E> runtime,
    void Function(List<ContError> errors) onElse,
    void Function(A value) onThen,
  ) _runCallbacks;

  const _LeafCont._(this._runCallbacks) : super._();

  void _start(
    ContRuntime<Object?> runtime,
    void Function(List<ContError> errors) onElse,
    void Function(Object? value) onThen,
  ) {
    _runCallbacks(
      runtime as ContRuntime<E>,
      onElse,
      onThen,
    );
  }
}

/// `source.thenDo(f)`.
final class _ThenDoCont<E, A, A2> extends Cont<E, A2> {
  final Cont<E, A> _source;
  final Cont<E, A2> Function(A value) _f;

  const _ThenDoCont(this._source, this._f) : super._();

  Cont<Object?, Object?> _apply(Object? value) {
    return _f(value as A);
  }
}

/// `source.elseDo(f)`.
final class _ElseDoCont<E, A> extends Cont<E, A> {
  final Cont<E, A> _source;
  final Cont<E, A> Function(List<ContError> errors) _f;

  const _ElseDoCont(this._source, this._f) : super._();

  Cont<Object?, Object?> _apply(List<ContError> errors) {
    return _f(errors);
  }
}

/// `Cont.fromDeferred(thunk)`.
final class _DeferCont<E, A> extends Cont<E, A> {
  final Cont<E, A> Function() _thunk;

  const _DeferCont(this._thunk) : super._();

  Cont<Object?, Object?> _build() {
    return _thunk();
  }
}

/// `source.local(f)`.
final class _LocalCont<E2, E, A> extends Cont<E2, A> {
  final Cont<E, A> _source;
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
/// runtime is cancelled, no node starts, no frame function runs and no
/// outcome is reported.
///
/// The frames live in the run, never in the [Cont], so a [Cont] can be
/// run any number of times, also concurrently.
final class _RunLoop {
  ContRuntime<Object?> _runtime;
  final void Function(List<ContError> errors) _onElse;
  final void Function(Object? value) _onThen;

  // _ThenDoCont and _ElseDoCont waiting for an outcome, and
  // _RuntimeFrames
  final List<Object> _frames = [];

  // the outcome being delivered: a value, or errors when _isElse
  bool _isElse = false;
  Object? _value;

  bool _isDone = false;

  // the leaf that is running, if any: reports of older leaves are
  // ignored, and a report while it starts continues the loop in place
  int _leafGeneration = 0;
  bool _isStarting = false;
  bool _hasReportedWhileStarting = false;

  _RunLoop(this._runtime, this._onElse, this._onThen);

  void start(Cont<Object?, Object?> cont) {
    _loop(cont);
  }

  void _report(int generation, bool isElse, Object? value) {
    if (_isDone || generation != _leafGeneration) {
      return;
    }
    _isElse = isElse;
    _value = value;
    if (_isStarting) {
      _hasReportedWhileStarting = true;
      return;
    }
    // reported after starting: resume with the frames left
    _loop(null);
  }

  void _fail(Object error, StackTrace st) {
    _isElse = true;
    _value = [ContError.withStackTrace(error, st)];
  }

  // Runs until a leaf is still running, the outcome is delivered or the
  // run is cancelled. A null [current] delivers the outcome in _isElse
  // and _value.
  void _loop(Cont<Object?, Object?>? current) {
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
        case _DeferCont():
          try {
            current = current._build();
          } catch (error, st) {
            // a throw from thunk terminates the computation
            _fail(error, st);
            current = null;
          }
        case _LocalCont():
          final runtime = _runtime;
          try {
            final innerRuntime =
                current._mapRuntime(runtime);
            _frames.add(_RuntimeFrame(runtime));
            _runtime = innerRuntime;
            current = current._source;
          } catch (error, st) {
            // a throw from f terminates the computation
            _fail(error, st);
            current = null;
          }
        case _LeafCont():
          if (!_startLeaf(current)) {
            return; // the leaf reports later and resumes the loop
          }
          current = null;
      }
    }
  }

  // Starts [leaf]. Returns true when it reported while starting.
  bool _startLeaf(_LeafCont<Object?, Object?> leaf) {
    final generation = ++_leafGeneration;
    _isStarting = true;
    _hasReportedWhileStarting = false;

    try {
      leaf._start(
        _runtime,
        (errors) {
          _report(generation, true, errors);
        },
        (value) {
          _report(generation, false, value);
        },
      );
    } catch (error, st) {
      // the leaf could not start, for example because the environment
      // is not of its type
      if (!_hasReportedWhileStarting) {
        _fail(error, st);
        _hasReportedWhileStarting = true;
      }
    }
    _isStarting = false;

    return _hasReportedWhileStarting;
  }

  // Pops frames until one handles the outcome in _isElse and _value,
  // and returns the computation it builds. Returns null once the
  // outcome went to the callbacks, or when the run was cancelled.
  Cont<Object?, Object?>? _unwind() {
    while (_frames.isNotEmpty) {
      final frame = _frames.removeLast();
      switch (frame) {
        case _RuntimeFrame(runtime: final runtime):
          _runtime = runtime;
        case _ThenDoCont() when !_isElse:
          if (_runtime.isCancelled()) {
            return null; // stop without an outcome
          }
          try {
            return frame._apply(_value);
          } catch (error, st) {
            // a throw from f terminates the computation
            _fail(error, st);
          }
        case _ElseDoCont() when _isElse:
          if (_runtime.isCancelled()) {
            return null; // stop without an outcome
          }
          final errors =
              (_value as List<ContError>).toList();
          try {
            return frame._apply(errors);
          } catch (error, st) {
            // a throw from f terminates the computation with it
            _fail(error, st);
          }
        default:
          break; // the frame handles another channel
      }
    }

    _finish();
    return null;
  }

  void _finish() {
    if (_isDone || _runtime.isCancelled()) {
      return;
    }
    _isDone = true;
    try {
      if (_isElse) {
        // defensive copy
        _onElse((_value as List<ContError>).toList());
      } else {
        _onThen(_value);
      }
    } catch (error, st) {
      try {
        _runtime
            .onPanic(ContError.withStackTrace(error, st));
      } catch (error, st) {
        _panic(ContError.withStackTrace(error, st));
      }
    }
  }
}
