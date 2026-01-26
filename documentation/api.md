# Jerelo API Reference

## Constructing

### Cont.fromRun
Creates a Cont from a run function that accepts an observer.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `run`: `void Function(ContObserver<A> observer)` - Function that executes the continuation
- **Description:** Constructs a continuation with guaranteed idempotence and exception catching. The run function receives an observer with `onValue` and `onTerminate` callbacks.

### Cont.fromFutureComp
Creates a Cont from a Future computation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `thunk`: `Future<A> Function()` - Function that returns a Future
- **Description:** Converts a Future-returning function into a continuation. Handles Future completion via `onValue` and errors via `onTerminate`.

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

### Cont.withRef
Creates a Cont with a mutable reference that manages resource lifecycle.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `initial`: `S` - Initial state value
  - `use`: `Cont<A> Function(Ref<S> ref)` - Function to use the reference
  - `release`: `Cont<()> Function(Ref<S> ref)` - Function to release/cleanup the reference
- **Description:** Resource management combinator that guarantees proper cleanup. The release function is called whether the use function succeeds or fails.

### Ref.commit
Atomically commits a state transformation.
- **Return type:** `Cont<V>`
- **Arguments:**
  - `f`: `Cont<(S, V) Function(S after)> Function(S before)` - Function that produces a state update computation
- **Description:** Performs a state transformation with consistency guarantees. Receives the state before and after, allowing safe concurrent state updates.

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

## Chaining

### flatMap
Chains a Cont-returning function to create dependent computations.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A value)` - Function that returns a continuation
- **Description:** Monadic bind operation. Sequences continuations where the second depends on the result of the first.

### flatMap0
Chains a Cont-returning zero-argument function.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function that returns a continuation
- **Description:** Similar to `flatMap` but ignores the current value.

### flatMapTo
Chains to a constant Cont.
- **Return type:** `Cont<A2>`
- **Arguments:**
  - `cont`: `Cont<A2>` - The continuation to chain to
- **Description:** Sequences to a fixed continuation, ignoring the current value.

### flatTap
Chains a side-effect continuation while preserving the original value.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A value)` - Side-effect function
- **Description:** Executes a continuation for its side effects, then returns the original value.

### flatTap0
Chains a zero-argument side-effect continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument side-effect function
- **Description:** Similar to `flatTap` but with a zero-argument function.

### flatTapTo
Chains to a constant side-effect continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `cont`: `Cont<A2>` - The side-effect continuation
- **Description:** Executes a fixed continuation for its side effects, preserving the original value.

### forkTap
Executes a side-effect continuation in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A a)` - Function that returns a side-effect continuation
- **Description:** Unlike `flatTap`, this method does not wait for the side-effect to complete. The side-effect continuation is started immediately, and the original value is returned without delay. Any errors from the side-effect are silently ignored.

### forkTap0
Executes a zero-argument side-effect continuation in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function that returns a side-effect continuation
- **Description:** Similar to `forkTap` but ignores the current value.

### forkTapTo
Executes a constant side-effect continuation in a fire-and-forget manner.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `other`: `Cont<A2>` - The side-effect continuation to execute
- **Description:** Similar to `forkTap0` but takes a fixed continuation instead of a function.

### flatMapZipWith
Chains and combines two continuation values.
- **Return type:** `Cont<A3>`
- **Arguments:**
  - `f`: `Cont<A2> Function(A value)` - Function to produce the second continuation
  - `combine`: `A3 Function(A a1, A2 a2)` - Function to combine both values
- **Description:** Sequences two continuations and combines their results using the provided function.

### flatMapZipWith0
Chains and combines with a zero-argument function.
- **Return type:** `Cont<A3>`
- **Arguments:**
  - `f`: `Cont<A2> Function()` - Zero-argument function to produce the second continuation
  - `combine`: `A3 Function(A a1, A2 a2)` - Function to combine both values
- **Description:** Similar to `flatMapZipWith` but the second continuation doesn't depend on the first value.

### flatMapZipWithTo
Chains and combines with a constant continuation.
- **Return type:** `Cont<A3>`
- **Arguments:**
  - `other`: `Cont<A2>` - The second continuation
  - `f`: `A3 Function(A a1, A2 a2)` - Function to combine both values
- **Description:** Sequences to a fixed continuation and combines their results.

### Cont.sequence
Runs a list of continuations sequentially and collects results.
- **Return type:** `Cont<List<A>>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to execute
- **Description:** Executes continuations one by one, collecting all successful values. Terminates on first error with stack-safe recursion.

## Merging

### Cont.both
Runs two continuations in parallel and combines their results.
- **Return type:** `Cont<C>`
- **Arguments:**
  - `left`: `Cont<A>` - First continuation
  - `right`: `Cont<B>` - Second continuation
  - `f`: `C Function(A a, B b)` - Function to combine results
- **Description:** Executes both continuations concurrently. Succeeds when both succeed, terminates if either fails.

### and
Instance method for combining with another continuation.
- **Return type:** `Cont<C>`
- **Arguments:**
  - `other`: `Cont<B>` - The other continuation
  - `f`: `C Function(A a, B b)` - Function to combine results
- **Description:** Convenient instance method wrapper for `Cont.both`.

### Cont.all
Runs multiple continuations in parallel and collects all results.
- **Return type:** `Cont<List<A>>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to execute
- **Description:** Executes all continuations concurrently. Succeeds only when all succeed, preserving result order.

## Racing

### Cont.raceForWinner
Races two continuations, returning the first successful value.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `left`: `Cont<A>` - First continuation
  - `right`: `Cont<A>` - Second continuation
- **Description:** Returns the result of whichever continuation succeeds first. Terminates only if both fail.

### raceForWinnerWith
Instance method to race with another continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `other`: `Cont<A>` - The other continuation to race with
- **Description:** Convenient instance method wrapper for `Cont.raceForWinner`.

### Cont.raceForWinnerAll
Races multiple continuations for the first success.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to race
- **Description:** Returns the first successful result. Terminates only when all fail.

### Cont.raceForLoser
Races two continuations, returning the value from the last to complete.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `left`: `Cont<A>` - First continuation
  - `right`: `Cont<A>` - Second continuation
- **Description:** Waits for both to complete, returns the slower one's value. Useful for timeout scenarios.

### raceForLoserWith
Instance method to race for loser with another continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `other`: `Cont<A>` - The other continuation to race with
- **Description:** Convenient instance method wrapper for `Cont.raceForLoser`.

### Cont.raceForLoserAll
Races multiple continuations for the last to complete.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to race
- **Description:** Returns the result of the last continuation to finish successfully.

## Recovering

### orElseWith
Provides a fallback continuation in case of termination.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function(List<ContError> errors)` - Function to produce fallback continuation
- **Description:** If the continuation terminates, executes the fallback. Accumulates errors from both attempts.

### orElseWith0
Provides a zero-argument fallback continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `Cont<A> Function()` - Zero-argument function to produce fallback
- **Description:** Similar to `orElseWith` but doesn't use the error information.

### orElse
Provides a constant fallback continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `other`: `Cont<A>` - The fallback continuation
- **Description:** If the continuation terminates, tries the fixed alternative.

### Cont.orElseAll
Tries multiple continuations until one succeeds.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `list`: `List<Cont<A>>` - List of continuations to try sequentially
- **Description:** Executes continuations one by one until one succeeds. Terminates only if all fail.

## Filtering

### filter
Conditionally allows a value to pass through.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `f`: `bool Function(A value)` - Predicate function
- **Description:** If the predicate returns false, the continuation terminates. Otherwise, passes the value through.

## Scheduling

### subscribeOn
Schedules the subscription (start) of the continuation.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `scheduler`: `ContScheduler` - Scheduler for execution
- **Description:** Controls which scheduler the continuation starts on. Useful for offloading work.

### observeOn
Schedules observation of both value and termination.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `scheduler`: `ContScheduler` - Scheduler for callbacks
- **Description:** Controls which scheduler callbacks are delivered on. Both `onValue` and `onTerminate` use the same scheduler.

### observeChannelOn
Separately schedules value and termination observations.
- **Return type:** `Cont<A>`
- **Arguments:**
  - `valueOn`: `ContScheduler` (optional, default: `ContScheduler.immediate`) - Scheduler for value callback
  - `terminateOn`: `ContScheduler` (optional, default: `ContScheduler.immediate`) - Scheduler for termination callback
- **Description:** Fine-grained control over callback scheduling with separate schedulers for success and failure paths.

## Extensions

### flatten
Flattens a nested Cont structure.
- **Return type:** `Cont<A>` (on `Cont<Cont<A>>`)
- **Arguments:** None
- **Description:** Converts `Cont<Cont<A>>` to `Cont<A>`. Equivalent to `flatMap((contA) => contA)`.

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

## ContScheduler

### ContScheduler.fromSchedule
Creates a scheduler from a schedule function.
- **Return type:** `ContScheduler`
- **Arguments:**
  - `schedule`: `void Function(void Function() action)` - Scheduling function
- **Description:** Factory constructor that wraps a custom scheduling function.

### ContScheduler.immediate
Immediate scheduler that executes synchronously.
- **Type:** `ContScheduler` (static constant)
- **Description:** Executes actions immediately without any delay or queuing.

### ContScheduler.delayed
Creates a scheduler with a delay.
- **Return type:** `ContScheduler`
- **Arguments:**
  - `duration`: `Duration` (optional, default: `Duration.zero`) - Delay before execution
- **Description:** Schedules actions to run after the specified duration using `Future.delayed`.

### ContScheduler.microtask
Creates a microtask scheduler.
- **Return type:** `ContScheduler`
- **Arguments:** None
- **Description:** Schedules actions on the microtask queue using `Future.microtask`.

### schedule
The scheduling function.
- **Type:** `void Function(void Function() action)`
- **Description:** Public final field containing the function that schedules actions.

## TestContScheduler

### TestContScheduler constructor
Creates a test scheduler for controlled execution.
- **Return type:** `TestContScheduler`
- **Arguments:** None
- **Description:** Creates a scheduler that queues actions for manual execution, useful for testing.

### asScheduler
Converts to a regular ContScheduler.
- **Return type:** `ContScheduler`
- **Arguments:** None
- **Description:** Returns a `ContScheduler` that enqueues actions in this test scheduler's queue.

### pendingCount
Returns the number of pending actions.
- **Return type:** `int`
- **Arguments:** None
- **Description:** Gets the count of actions waiting in the queue.

### isIdle
Checks if the scheduler has no pending actions.
- **Return type:** `bool`
- **Arguments:** None
- **Description:** Returns `true` if the queue is empty, `false` otherwise.

### flush
Executes queued actions in FIFO order.
- **Return type:** `void`
- **Arguments:**
  - `maxSteps`: `int` (optional, default: `-1`) - Maximum number of actions to execute
- **Description:** Runs queued actions one by one. Protected against infinite loops from self-enqueuing actions. Use `maxSteps` to limit execution count (-1 means unlimited).
