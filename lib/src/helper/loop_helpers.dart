part of '../cont.dart';

Cont<E, A> _thenWhile<E, A>(
  Cont<E, A> cont,
  bool Function(A value) predicate,
) {
  return Cont.fromRun((runtime, observer) {
    _stackSafeLoop<
      _Either<(), _Either<(), _Either<A, List<ContError>>>>,
      (),
      _Either<(), _Either<A, List<ContError>>>
    >(
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
                          ContError.withStackTrace(
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
                  ContError.withStackTrace(error, st),
                ]),
              ),
            ),
          );
        }
      },
      escape: (result) {
        switch (result) {
          case _Left<(), _Either<A, List<ContError>>>():
            // cancellation
            return;
          case _Right<(), _Either<A, List<ContError>>>(
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

Cont<E, A> _elseWhile<E, A>(
  Cont<E, A> cont,
  bool Function(List<ContError> errors) predicate,
) {
  return Cont.fromRun((runtime, observer) {
    _stackSafeLoop<
      _Either<(), _Either<(), _Either<A, List<ContError>>>>,
      (),
      _Either<(), _Either<A, List<ContError>>>
    >(
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
                          ContError.withStackTrace(
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
                  ContError.withStackTrace(error, st),
                ]),
              ),
            ),
          );
        }
      },
      escape: (result) {
        switch (result) {
          case _Left<(), _Either<A, List<ContError>>>():
            // cancellation
            return;
          case _Right<(), _Either<A, List<ContError>>>(
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
