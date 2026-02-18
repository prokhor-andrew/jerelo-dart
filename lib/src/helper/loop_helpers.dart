part of '../cont.dart';

/// Implementation of the success-path looping operator.
///
/// Repeatedly runs [cont] as long as [predicate] returns `true` for the
/// produced value. Stops and succeeds when the predicate returns `false`,
/// or terminates if the continuation itself terminates. Uses
/// [_stackSafeLoop] for stack safety across both synchronous and
/// asynchronous iterations.
Cont<E, F, A> _thenWhile<E, F, A>(
  Cont<E, F, A> cont,
  bool Function(A value) predicate,
) {
  return Cont.fromRun((runtime, observer) {
    _stackSafeLoop<
        _Either<(),
            _Either<(), _Either<A, List<ContError<F>>>>>,
        (),
        _Either<(), _Either<A, List<ContError<F>>>>>(
      seed: _Left(()),
      keepRunningIf: (state) {
        switch (state) {
          case _Left():
            // Keep running - need to execute the continuation again
            return _StackSafeLoopPolicyKeepRunning(());
          case _Right(value: final result):
            // Stop - we have either a successful value or termination errors
            return _StackSafeLoopPolicyStop(result);
        }
      },
      computation: (_, callback) {
        try {
          cont._run(
            runtime,
            ContObserver._(
              (errors) {
                if (runtime.isCancelled()) {
                  callback(_Right(_Left(())));
                  return;
                }
                // Terminated - stop the loop with errors
                callback(
                  _Right(_Right(_Right([...errors]))),
                );
              },
              (a) {
                if (runtime.isCancelled()) {
                  callback(_Right(_Left(())));
                  return;
                }

                try {
                  // Check the predicate
                  if (!predicate(a)) {
                    // Predicate satisfied - stop with success
                    callback(_Right(_Right(_Left(a))));
                  } else {
                    // Predicate not satisfied - retry
                    callback(_Left(()));
                  }
                } catch (error, st) {
                  // Predicate threw an exception
                  callback(
                    _Right(
                      _Right(
                        _Right([
                          ThrownError(
                            error,
                            st,
                          ),
                        ]),
                      ),
                    ),
                  );
                }
              },
            ),
          );
        } catch (error, st) {
          callback(
            _Right(
              _Right(
                _Right([
                  ThrownError(error, st),
                ]),
              ),
            ),
          );
        }
      },
      escape: (result) {
        switch (result) {
          case _Left<(), _Either<A, List<ContError<F>>>>():
            // cancellation
            return;
          case _Right<(), _Either<A, List<ContError<F>>>>(
              value: final result,
            ):
            switch (result) {
              case _Left(value: final a):
                observer.onThen(a);
                return;
              case _Right(value: final errors):
                observer.onElse(errors);
                return;
            }
        }
      },
    );
  });
}

/// Implementation of the termination-path retry loop.
///
/// Repeatedly runs [cont] while it terminates and [predicate] returns
/// `true` for the termination errors. Stops retrying and propagates the
/// termination when the predicate returns `false`, or succeeds if the
/// continuation eventually succeeds. Uses [_stackSafeLoop] for stack
/// safety across both synchronous and asynchronous iterations.
Cont<E, F, A> _elseWhile<E, F, A>(
  Cont<E, F, A> cont,
  bool Function(List<ContError<F>> errors) predicate,
) {
  return Cont.fromRun((runtime, observer) {
    _stackSafeLoop<
        _Either<(),
            _Either<(), _Either<A, List<ContError<F>>>>>,
        (),
        _Either<(), _Either<A, List<ContError<F>>>>>(
      seed: _Left(()),
      keepRunningIf: (state) {
        switch (state) {
          case _Left():
            // Keep running - need to execute the continuation again
            return _StackSafeLoopPolicyKeepRunning(());
          case _Right(value: final result):
            // Stop - we have either a successful value or termination errors
            return _StackSafeLoopPolicyStop(result);
        }
      },
      computation: (_, callback) {
        try {
          cont._run(
            runtime,
            ContObserver._(
              (errors) {
                if (runtime.isCancelled()) {
                  callback(_Right(_Left(())));
                  return;
                }

                try {
                  // Check the predicate
                  if (predicate(errors)) {
                    // Predicate satisfied - retry
                    callback(_Left(()));
                  } else {
                    // Predicate not satisfied - stop with errors
                    callback(
                      _Right(_Right(_Right([...errors]))),
                    );
                  }
                } catch (error, st) {
                  // Predicate threw an exception
                  callback(
                    _Right(
                      _Right(
                        _Right([
                          ThrownError(
                            error,
                            st,
                          ),
                        ]),
                      ),
                    ),
                  );
                }
              },
              (a) {
                if (runtime.isCancelled()) {
                  callback(_Right(_Left(())));
                  return;
                }
                // Successful value - stop the loop with success
                callback(_Right(_Right(_Left(a))));
              },
            ),
          );
        } catch (error, st) {
          callback(
            _Right(
              _Right(
                _Right([
                  ThrownError(error, st),
                ]),
              ),
            ),
          );
        }
      },
      escape: (result) {
        switch (result) {
          case _Left<(), _Either<A, List<ContError<F>>>>():
            // cancellation
            return;
          case _Right<(), _Either<A, List<ContError<F>>>>(
              value: final result,
            ):
            switch (result) {
              case _Left(value: final a):
                observer.onThen(a);
                return;
              case _Right(value: final errors):
                observer.onElse(errors);
                return;
            }
        }
      },
    );
  });
}
