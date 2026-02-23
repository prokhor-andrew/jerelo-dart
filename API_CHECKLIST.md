# Jerelo API Checklist

## Cont (core class)

### Static Factory Methods
- [ ] `Cont.fromRun` -- create from a run function with idempotence/exception guarantees
- [ ] `Cont.fromDeferred` -- lazily evaluate a continuation-returning thunk
- [ ] `Cont.crash` -- immediately crash
- [ ] `Cont.of` -- immediately succeed with a value
- [ ] `Cont.error` -- immediately terminate with an error
- [ ] `Cont.askThen` -- retrieve the environment as a success value
- [ ] `Cont.askElse` -- retrieve the environment as an error
- [ ] `Cont.both` -- run two continuations and combine their results
- [ ] `Cont.all` -- run multiple continuations and collect all results
- [ ] `Cont.either` -- race two continuations, return the first success
- [ ] `Cont.any` -- race multiple continuations, return the first success
- [ ] `Cont.merge` -- merge two continuations on the crash channel
- [ ] `Cont.bracket` -- safe resource management (acquire/release/use)

### Instance Methods
- [ ] `run` -- execute the continuation with callbacks, returns a cancel token
- [ ] `runWith` -- execute with an explicit runtime and observer

---

## ContCrash (sealed class)

- [ ] `ContCrash.tryCatch` -- wrap a function call, returning a NormalCrash if it throws

### NormalCrash
- [ ] `error` property
- [ ] `stackTrace` property

### MergedCrash
- [ ] `left` property
- [ ] `right` property

### ListedCrash
- [ ] `crashes` property

---

## ContRuntime

- [ ] `isCancelled` -- check if cancelled
- [ ] `env` -- returns the current environment value
- [ ] `copyUpdateEnv` -- create a copy with a different environment
- [ ] `extendCancellation` -- extend the cancellation check with an additional predicate

---

## ContObserver / SafeObserver

- [ ] `onCrash` callback
- [ ] `onElse` callback
- [ ] `onThen` callback
- [ ] `copyUpdateOnCrash`
- [ ] `copyUpdateOnElse`
- [ ] `copyUpdateOnThen`
- [ ] `copyUpdate`
- [ ] `thenAbsurdify` (extension)
- [ ] `elseAbsurdify` (extension)
- [ ] `absurdify` (extension)
- [ ] `thenAbsurd` (on `ContObserver<F, Never>`)
- [ ] `elseAbsurd` (on `ContObserver<Never, A>`)

---

## ContCancelToken

- [ ] `isCancelled` -- check if cancel was called
- [ ] `cancel` -- signal cancellation

---

## OkPolicy

- [ ] `OkPolicy.sequence` -- sequential execution
- [ ] `OkPolicy.quitFast` -- parallel, quit on first failure
- [ ] `OkPolicy.runAll` -- parallel, run all and combine failures

---

## CrashPolicy

- [ ] `CrashPolicy.sequence` -- sequential crash policy
- [ ] `CrashPolicy.quitFast` -- parallel quit-fast crash policy
- [ ] `CrashPolicy.runAll` -- parallel run-all crash policy

---

## Then (success path) operators

### thenDo -- monadic bind (chain on success)
- [ ] `thenDo`
- [ ] `thenDo0`
- [ ] `thenDoWithEnv`
- [ ] `thenDoWithEnv0`

### thenTap -- side-effect on success, preserves original value
- [ ] `thenTap`
- [ ] `thenTap0`
- [ ] `thenTapWithEnv`
- [ ] `thenTapWithEnv0`

### thenZip -- chain and combine two success values
- [ ] `thenZip`
- [ ] `thenZip0`
- [ ] `thenZipWithEnv`
- [ ] `thenZipWithEnv0`

### thenMap -- pure transformation of success value
- [ ] `thenMap`
- [ ] `thenMap0`
- [ ] `thenMapWithEnv`
- [ ] `thenMapWithEnv0`
- [ ] `thenMapTo`

### thenIf -- filter: succeed if predicate true, else error
- [ ] `thenIf`
- [ ] `thenIf0`
- [ ] `thenIfWithEnv`
- [ ] `thenIfWithEnv0`

### thenUntil -- loop until predicate returns true
- [ ] `thenUntil`
- [ ] `thenUntil0`
- [ ] `thenUntilWithEnv`
- [ ] `thenUntilWithEnv0`

### thenForever -- loop indefinitely on success path
- [ ] `thenForever`

### thenFork (internal part) -- fork on success
- [ ] `thenFork`
- [ ] `thenFork0`
- [ ] `thenForkWithEnv`
- [ ] `thenForkWithEnv0`

### thenWhile (internal part) -- while loop on success
- [ ] `thenWhile`
- [ ] `thenWhile0`
- [ ] `thenWhileWithEnv`
- [ ] `thenWhileWithEnv0`

### demote -- unconditionally demote success to error
- [ ] `demote`
- [ ] `demote0`
- [ ] `demoteWithEnv`
- [ ] `demoteWithEnv0`
- [ ] `demoteWith`

---

## Else (error path) operators

### elseDo -- fallback continuation on error
- [ ] `elseDo`
- [ ] `elseDo0`
- [ ] `elseDoWithEnv`
- [ ] `elseDoWithEnv0`

### elseTap -- side-effect on error
- [ ] `elseTap`
- [ ] `elseTap0`
- [ ] `elseTapWithEnv`
- [ ] `elseTapWithEnv0`

### elseZip -- fallback with error accumulation
- [ ] `elseZip`
- [ ] `elseZip0`
- [ ] `elseZipWithEnv`
- [ ] `elseZipWithEnv0`

### elseMap -- transform the error
- [ ] `elseMap`
- [ ] `elseMap0`
- [ ] `elseMapWithEnv`
- [ ] `elseMapWithEnv0`
- [ ] `elseMapTo`

### elseUnless -- promote error to success when predicate is false
- [ ] `elseUnless`
- [ ] `elseUnless0`
- [ ] `elseUnlessWithEnv`
- [ ] `elseUnlessWithEnv0`

### elseUntil -- retry until predicate returns true on error
- [ ] `elseUntil`
- [ ] `elseUntil0`
- [ ] `elseUntilWithEnv`
- [ ] `elseUntilWithEnv0`

### elseForever -- retry on error indefinitely
- [ ] `elseForever`

### elseFork (internal part) -- fork on error
- [ ] `elseFork`
- [ ] `elseFork0`
- [ ] `elseForkWithEnv`
- [ ] `elseForkWithEnv0`

### elseWhile (internal part) -- while loop on error
- [ ] `elseWhile`
- [ ] `elseWhile0`
- [ ] `elseWhileWithEnv`
- [ ] `elseWhileWithEnv0`

### promote -- promote error to success value
- [ ] `promote`
- [ ] `promote0`
- [ ] `promoteWithEnv`
- [ ] `promoteWithEnv0`
- [ ] `promoteWith`

---

## Crash (crash path) operators

### crashDo -- fallback continuation on crash
- [ ] `crashDo`
- [ ] `crashDo0`
- [ ] `crashDoWithEnv`
- [ ] `crashDoWithEnv0`

### crashTap -- side-effect on crash
- [ ] `crashTap`
- [ ] `crashTap0`
- [ ] `crashTapWithEnv`
- [ ] `crashTapWithEnv0`

### crashZip (internal part) -- crash with accumulation
- [ ] `crashZip`
- [ ] `crashZip0`
- [ ] `crashZipWithEnv`
- [ ] `crashZipWithEnv0`

### crashUnless -- conditionally recover from crash
- [ ] `crashUnlessThen`
- [ ] `crashUnlessThen0`
- [ ] `crashUnlessThenWithEnv`
- [ ] `crashUnlessThenWithEnv0`
- [ ] `crashUnlessElse`
- [ ] `crashUnlessElse0`
- [ ] `crashUnlessElseWithEnv`
- [ ] `crashUnlessElseWithEnv0`

### crashUntil -- retry until predicate returns true on crash
- [ ] `crashUntil`
- [ ] `crashUntil0`
- [ ] `crashUntilWithEnv`
- [ ] `crashUntilWithEnv0`

### crashRecover -- recover from crash to success or error
- [ ] `crashRecoverThen`
- [ ] `crashRecoverThen0`
- [ ] `crashRecoverThenWithEnv`
- [ ] `crashRecoverThenWithEnv0`
- [ ] `crashRecoverThenWith`
- [ ] `crashRecoverElse`
- [ ] `crashRecoverElse0`
- [ ] `crashRecoverElseWithEnv`
- [ ] `crashRecoverElseWithEnv0`
- [ ] `crashRecoverElseWith`

### crashFork (internal part) -- fork on crash
- [ ] `crashFork`
- [ ] `crashFork0`
- [ ] `crashForkWithEnv`
- [ ] `crashForkWithEnv0`

### crashWhile (internal part) -- while loop on crash
- [ ] `crashWhile`
- [ ] `crashWhile0`
- [ ] `crashWhileWithEnv`
- [ ] `crashWhileWithEnv0`

### crashForever -- retry on crash indefinitely
- [ ] `crashForever`

---

## Combos (instance wrappers)

- [ ] `and` -- instance wrapper for `Cont.both`
- [ ] `or` -- instance wrapper for `Cont.either`
- [ ] `mergeWith` -- instance wrapper for `Cont.merge`

---

## Environment operators

- [ ] `local` -- run with a transformed environment
- [ ] `local0` -- run with an environment from a zero-arg function
- [ ] `withEnv` -- run with a fixed environment value
- [ ] `thenInject` -- use success value as environment for another continuation
- [ ] `injectedByThen` -- pipe environment from another's success value
- [ ] `elseInject` -- use error as environment for another continuation
- [ ] `injectedByElse` -- pipe environment from another's error value

---

## Decorate

- [ ] `decorate` -- wrap execution with middleware (logging, timing, etc.)

---

## Never-type extensions

- [ ] `thenAbsurdify` -- if A is Never, convert via thenAbsurd
- [ ] `elseAbsurdify` -- if F is Never, convert via elseAbsurd
- [ ] `absurdify` -- apply both absurdify operations
- [ ] `elseAbsurd` (on `Cont<E, Never, A>`) -- widen error type
- [ ] `thenAbsurd` (on `Cont<E, F, Never>`) -- widen success type

---

## Flatten

- [ ] `flatten` (on `Cont<E, F, Cont<E, F, A>>`) -- flatten nested Cont
