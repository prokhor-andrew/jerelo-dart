# Jerelo API Reference

## Constructing

### Cont.fromRun
Creates a Cont from a run function that accepts an observer.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `run`: `void Function(ContObserver<A> observer)` - Function that executes the continuation
- **Description:** Constructs a continuation with guaranteed idempotence and exception catching. The run function receives an observer with `onValue` and `onTerminate` callbacks.

### Cont.fromDeferred
Creates a Cont from a deferred continuation computation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `thunk`: `Cont<A> Function()` - Function that returns a Cont
- **Description:** Lazily evaluates a continuation-returning function. The inner Cont is not created until the outer one is executed.

### Cont.of
Creates a Cont that immediately succeeds with a value.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `value`: `A` - The value to wrap
- **Description:** Identity operation that wraps a pure value in a continuation context.

### Cont.terminate
Creates a Cont that immediately terminates with optional errors.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `errors`: `List<ContError>` (optional, default: `[]`) - List of errors to terminate with
- **Description:** Creates a continuation that terminates without producing a value. Used to represent failure states.

### Cont.bracket
Manages resource lifecycle with guaranteed cleanup.
- **Return type:** `Cont<A>`
- **Type parameters:**
  - `R` - The type of the resource
  - `A` - The type of the result
- **Arguments:**
  - `acquire`: `Cont<R>` - Continuation that acquires the resource
  - `release`: `Cont<()> Function(R resource)` - Function that returns a continuation to release the resource
  - `use`: `Cont<A> Function(R resource)` - Function that returns a continuation using the resource
- **Description:** Ensures a resource is properly released after use, even if an error occurs. The execution order is: acquire → use → release. If `use` fails, `release` still runs and errors are accumulated. This is the functional equivalent of try-with-resources or using statements.

## Transforming

### map
Transforms the value inside a Cont using a pure function.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `f`: `A2 Function(A value)` - Transformation function
- **Description:** Applies a function to the successful value of the continuation without affecting the termination case.

### map0
Transforms the value inside a Cont using a zero-argument function.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `f`: `A2 Function()` - Zero-argument transformation function
- **Description:** Similar to `map` but ignores the current value and computes a new one.

### mapTo
Replaces the value inside a Cont with a constant.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `value`: `A2` - The constant value to replace with
- **Description:** Discards the current value and replaces it with a fixed value.

### hoist
Transforms the execution of the continuation using a natural transformation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `void Function(void Function(ContObserver<A>) run, ContObserver<A> observer)` - A transformation function that receives the run function and observer, and implements custom execution logic
- **Description:** Applies a function that wraps or modifies the underlying run behavior. The transformation function receives both the original run function and the observer, allowing custom execution behavior to be injected. Useful for intercepting execution to add middleware-like behavior such as logging, timing, or modifying how observers receive callbacks.

## Chaining

### then
Chains a Cont-returning function to create dependent computations.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A value)` - Function that returns a continuation
- **Description:** Monadic bind operation. Sequences continuations where the second depends on the result of the first.

### then0
Chains a Cont-returning zero-argument function.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function that returns a continuation
- **Description:** Similar to `then` but ignores the current value.

### tap
Chains a side-effect continuation while preserving the original value.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A value)` - Side-effect function
- **Description:** Executes a continuation for its side effects, then returns the original value.

### tap0
Chains a zero-argument side-effect continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument side-effect function
- **Description:** Similar to `tap` but with a zero-argument function.

### fork
Executes a side-effect continuation in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A a)` - Function that returns a side-effect continuation
- **Description:** Unlike `tap`, this method does not wait for the side-effect to complete. 
The side-effect continuation is started immediately, and the original value is returned without delay.
Any errors from the side-effect are silently ignored.

### fork0
Executes a zero-argument side-effect continuation in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function that returns a side-effect continuation
- **Description:** Similar to `fork` but ignores the current value.

### zip
Chains and combines two continuation values.
- **Return type:** `Cont<A3>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A value)` - Function to produce the second continuation
  - `combine`: `A3 Function(A a1, A2 a2)` - Function to combine both values
- **Description:** Sequences two continuations and combines their results using the provided function.

### zip0
Chains and combines with a zero-argument function.
- **Return type:** `Cont<A3>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function to produce the second continuation
  - `combine`: `A3 Function(A a1, A2 a2)` - Function to combine both values
- **Description:** Similar to `zip` but the second continuation doesn't depend on the first value.


## Branching

### when
Conditionally succeeds only when the predicate is satisfied.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `predicate`: `bool Function(A value)` - Function that tests the value
- **Description:** Filters the continuation based on the predicate. If the predicate returns `true`, the continuation succeeds with the value. If the predicate returns `false`, the continuation terminates without errors. This is useful for conditional execution where you want to treat a predicate failure as termination rather than an error.

### asLongAs
Repeatedly executes the continuation as long as the predicate returns `true`, stopping when it returns `false`.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `predicate`: `bool Function(A value)` - Function that tests the value. Returns `true` to continue looping, or `false` to stop and succeed with the value
- **Description:** Runs the continuation in a loop, testing each result with the predicate. The loop continues as long as the predicate returns `true`, and stops successfully when the predicate returns `false`. The loop is stack-safe and handles asynchronous continuations correctly. If the continuation terminates or if the predicate throws an exception, the loop stops and propagates the errors. This is useful for retry logic, polling, or repeating an operation while a condition holds.

### until
Repeatedly executes the continuation until the predicate returns `true`.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `predicate`: `bool Function(A value)` - Function that tests the value. Returns `true` to stop the loop and succeed, or `false` to continue looping
- **Description:** Runs the continuation in a loop, testing each result with the predicate. The loop continues while the predicate returns `false`, and stops successfully when the predicate returns `true`. This is the inverse of `asLongAs` - implemented as `asLongAs((a) => !predicate(a))`. Use this when you want to retry until a condition is met.

### forever
Repeatedly executes the continuation indefinitely.
- **Return type:** `Cont<Never>`
- **Arguments:** None
- **Description:** Runs the continuation in an infinite loop that never stops on its own. The loop only terminates if the underlying continuation terminates with an error. The return type `Cont<Never>` indicates that this continuation never produces a value - it either runs forever or terminates with errors. This is useful for daemon-like processes, server loops, event loops, and background tasks that should run continuously.

## Merging

### Cont.both
Runs two continuations and combines their results according to the specified policy.
- **Return type:** `Cont<A3>`
- **Type parameters:**
  - `A1` - The type of the first continuation's result
  - `A2` - The type of the second continuation's result
  - `A3` - The type of the combined result
- **Arguments:**
  - `left`: `Cont<A1>` - First continuation
  - `right`: `Cont<A2>` - Second continuation
  - `combine`: `A3 Function(A1 a1, A2 a2)` - Function to combine results
  - `policy`: `ContPolicy<List<ContError>>` - Execution policy (required)
- **Description:** Executes both continuations and combines their values using `combine`. The execution behavior depends on the provided policy:
  - `SequencePolicy`: Runs `left` then `right` sequentially.
  - `MergeWhenAllPolicy`: Runs both in parallel, waits for both to complete, and merges errors if both fail.
  - `QuitFastPolicy`: Runs both in parallel, terminates immediately if either fails.

### and
Instance method for combining with another continuation.
- **Return type:** `Cont<A3>`
- **Type parameters:**
  - `A2` - The type of the other continuation's result
  - `A3` - The type of the combined result
- **Arguments:**
  - `right`: `Cont<A2>` - The other continuation
  - `combine`: `A3 Function(A a1, A2 a2)` - Function to combine results
  - `policy`: `ContPolicy<List<ContError>>` - Execution policy (required)
- **Description:** Convenient instance method wrapper for `Cont.both`. Executes this continuation and `right` according to the specified policy, then combines their values.

### Cont.all
Runs multiple continuations and collects all results according to the specified policy.
- **Return type:** `Cont<List<A>>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to execute
  - `policy`: `ContPolicy<List<ContError>>` - Execution policy (required)
- **Description:** Executes all continuations in `list` and collects their values into a list. The execution behavior depends on the provided policy:
  - `SequencePolicy`: Runs continuations one by one in order, stops at first failure.
  - `MergeWhenAllPolicy`: Runs all in parallel, waits for all to complete, and merges errors if any fail.
  - `QuitFastPolicy`: Runs all in parallel, terminates immediately on first failure.

## Racing

### Cont.either
Races two continuations, returning the first successful value.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `left`: `Cont<A>` - First continuation to try
  - `right`: `Cont<A>` - Second continuation to try
  - `combine`: `List<ContError> Function(List<ContError>, List<ContError>)` - Function to combine error lists if both fail
  - `policy`: `ContPolicy<A>` - Execution policy (required)
- **Description:** Executes both continuations and returns the result from whichever succeeds first. If both fail, combines their errors using `combine`. The execution behavior depends on the provided policy:
  - `SequencePolicy`: Tries `left` first, then `right` if `left` fails.
  - `MergeWhenAllPolicy`: Runs both in parallel, returns first success or merges results/errors if both complete.
  - `QuitFastPolicy`: Runs both in parallel, returns immediately on first success.

### or
Instance method for racing this continuation with another.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `right`: `Cont<A>` - The other continuation to race with
  - `combine`: `List<ContError> Function(List<ContError>, List<ContError>)` - Function to combine error lists if both fail
  - `policy`: `ContPolicy<A>` - Execution policy (required)
- **Description:** Convenient instance method wrapper for `Cont.either`. Races this continuation against `right`, returning the first successful value.

### Cont.any
Races multiple continuations, returning the first successful value.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to race
  - `policy`: `ContPolicy<A>` - Execution policy (required)
- **Description:** Executes all continuations in `list` and returns the first one that succeeds. If all fail, collects all errors. The execution behavior depends on the provided policy:
  - `SequencePolicy`: Tries continuations one by one in order until one succeeds.
  - `MergeWhenAllPolicy`: Runs all in parallel, returns first success or merges results if all complete.
  - `QuitFastPolicy`: Runs all in parallel, returns immediately on first success.

## Recovering

### elseThen
Provides a fallback continuation in case of termination.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function(List<ContError> errors)` - Function to produce fallback continuation
- **Description:** If the continuation terminates, executes the fallback. If the fallback also fails, only the fallback's errors are propagated.

### elseThen0
Provides a zero-argument fallback continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function()` - Zero-argument function to produce fallback
- **Description:** Similar to `elseThen` but doesn't use the error information.

### elseTap
Executes a side-effect continuation on termination while preserving the original termination.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function(List<ContError> errors)` - Function that returns a side-effect continuation
- **Description:** If the continuation terminates, executes the side-effect continuation for its effects, then terminates with the original errors. Unlike `elseThen`, this does not attempt to recover - it always propagates the termination. Useful for logging, cleanup, or notification on failure without altering the error flow.

### elseTap0
Executes a zero-argument side-effect continuation on termination.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function()` - Zero-argument function that returns a side-effect continuation
- **Description:** Similar to `elseTap` but ignores the error information. The side-effect is executed regardless of the specific errors that caused termination.

### elseZip
Attempts a fallback continuation and combines errors from both attempts.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function(List<ContError>)` - Function that receives original errors and produces a fallback continuation
  - `combine`: `List<ContError> Function(List<ContError>, List<ContError>)` - Function to combine error lists from both attempts
- **Description:** If the continuation terminates, executes the fallback. If the fallback also terminates, combines errors from both attempts using the provided `combine` function before terminating. Unlike `elseThen`, which only keeps the second error list, this method accumulates and combines errors from both attempts.

### elseZip0
Zero-argument version of elseZip.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function()` - Zero-argument function that produces a fallback continuation
  - `combine`: `List<ContError> Function(List<ContError>, List<ContError>)` - Function to combine error lists from both attempts
- **Description:** Similar to `elseZip` but doesn't use the original error information when producing the fallback continuation.

### elseFork
Executes a side-effect continuation on termination in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function(List<ContError> errors)` - Function that returns a side-effect continuation
- **Description:** If the continuation terminates, starts the side-effect continuation without waiting for it to complete. 
Unlike `elseTap`, this does not wait for the side-effect to finish before propagating the termination.
Any errors from the side-effect are silently ignored. Useful for async logging or fire-and-forget notifications on failure.

### elseFork0
Executes a zero-argument side-effect continuation on termination in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function that returns a side-effect continuation
- **Description:** Similar to `elseFork` but ignores the error information.

## Extensions

### flatten
Flattens a nested Cont structure.
- **Return type:** `Cont<A>` (on `Cont<Cont<A>>`)
- **Arguments:** None
- **Description:** Converts `Cont<Cont<A>>` to `Cont<A>`. Equivalent to `then((contA) => contA)`.

### trap
Executes a continuation that never produces a value.
- **Return type:** `void` (on `Cont<Never>`)
- **Arguments:**
  - `onTerminate`: `void Function(List<ContError> errors)` - Callback for termination
- **Description:** Convenience method for `Cont<Never>` that executes the continuation with only a termination handler. Since `Cont<Never>` never produces a value, the value callback is unnecessary and omitted.

## Running

### run
Executes the continuation with provided callbacks.
- **Return type:** `void`
- **Arguments:**
  - `onTerminate`: `void Function(List<ContError> errors)` - Callback for termination
  - `onValue`: `void Function(A value)` - Callback for success
- **Description:** Initiates execution of the continuation with separate handlers for success and failure.

### runWith
Executes the continuation with an observer.
- **Return type:** `void`
- **Arguments:**
  - `observer`: `ContObserver<A>` - Observer containing callbacks
- **Description:** Alternative to `run` that accepts an observer object instead of separate callbacks.

### ff
Executes the continuation in a fire-and-forget manner.
- **Return type:** `void`
- **Arguments:** None
- **Description:** Runs the continuation without waiting for the result. Both success and failure outcomes are ignored. This is useful for side-effects that should run asynchronously without blocking or requiring error handling. Equivalent to `runWith(ContObserver.ignore())`.

## ContObserver

### ContObserver constructor
Creates an observer with termination and value handlers.
- **Return type:** `ContObserver<A>`
- **Arguments:**
  - `_onTerminate`: `void Function(List<ContError> errors)` - Handler for termination
  - `onValue`: `void Function(A value)` - Handler for successful value
- **Description:** Constructs an observer that handles both success and failure cases.

### ContObserver.ignore
Creates an observer that ignores all callbacks.
- **Return type:** `ContObserver<A>`
- **Arguments:** None
- **Description:** Useful for fire-and-forget scenarios where results are not needed.

### onValue
The value callback function.
- **Type:** `void Function(A value)`
- **Description:** Public field containing the success callback handler.

### onTerminate
Invokes the termination callback.
- **Return type:** `void`
- **Arguments:**
  - `errors`: `List<ContError>` (optional, default: `[]`) - List of errors
- **Description:** Calls the internal termination handler with the provided errors.

### copyUpdateOnTerminate
Creates a new observer with updated termination handler.
- **Return type:** `ContObserver<A>`
- **Arguments:**
  - `onTerminate`: `void Function(List<ContError> errors)` - New termination handler
- **Description:** Returns a copy of the observer with a different termination callback, preserving the value callback.

### copyUpdateOnValue
Creates a new observer with updated value handler and different type.
- **Return type:** `ContObserver<A2>`
- **Arguments:**
  - `onValue`: `void Function(A2 value)` - New value handler
- **Description:** Returns a copy of the observer with a different value callback type, preserving the termination callback.

## ContError

### ContError constructor
Creates an error wrapper containing an error and stack trace.
- **Return type:** `ContError`
- **Arguments:**
  - `error`: `Object` - The error object
  - `stackTrace`: `StackTrace` - The stack trace
- **Description:** Immutable error container used throughout the continuation system.

### error
The error object.
- **Type:** `Object`
- **Description:** Public final field containing the error.

### stackTrace
The stack trace.
- **Type:** `StackTrace`
- **Description:** Public final field containing the stack trace where the error occurred.

### toString
Returns a string representation of the error.
- **Return type:** `String`
- **Arguments:** None
- **Description:** Provides a readable string representation of the error in the format `{ error=<error>, stackTrace=<stackTrace> }`.

## ContPolicy

Execution policy for parallel continuation operations. Defines how multiple continuations should be executed and how their results or errors should be combined. Used by operations like `Cont.both`, `Cont.all`, `Cont.either`, `Cont.any`, and their instance method variants.

### ContPolicy.sequence
Creates a sequential execution policy.
- **Return type:** `ContPolicy<T>`
- **Arguments:** None
- **Description:** Operations are executed one after another in order. For `all`/`both`, execution stops at the first failure. For `any`/`either`, execution continues until one succeeds or all fail. This provides predictable execution order but may be slower for independent operations.

### ContPolicy.mergeWhenAll
Creates a merge-when-all policy with a custom combiner.
- **Return type:** `MergeWhenAllPolicy<T>`
- **Arguments:**
  - `combine`: `T Function(T acc, T value)` - Function to merge accumulated and new values
- **Description:** All operations are executed in parallel. Results or errors are accumulated using the provided `combine` function. The function receives the accumulated value and the new value, returning the combined result. This is useful when you need to collect all errors or results from parallel operations.

### ContPolicy.quitFast
Creates a quit-fast policy.
- **Return type:** `ContPolicy<T>`
- **Arguments:** None
- **Description:** Terminates immediately when a decisive result is reached. For `all`/`both` operations, quits on the first failure. For `any`/`either` operations, quits on the first success. Provides the fastest feedback but may leave other operations running. Use this when you want to fail-fast or succeed-fast without waiting for all operations to complete.
