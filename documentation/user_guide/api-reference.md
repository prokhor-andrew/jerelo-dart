# API Reference

Complete reference of all public APIs in Jerelo, organized by category.

## Constructors and Factory Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `fromRun` | `Cont<E, A> fromRun(void Function(ContRuntime<E>, ContObserver<A>) run)` | Create a continuation from a run function |
| `of` | `Cont<E, A> of(A value)` | Create a continuation that immediately succeeds with a value |
| `stop` | `Cont<E, A> stop([List<ContError> errors])` | Create a continuation that immediately terminates with optional errors |
| `ask` | `Cont<E, E> ask<E>()` | Retrieve the current environment value |
| `fromDeferred` | `Cont<E, A> fromDeferred(Cont<E, A> Function() thunk)` | Lazily evaluate a continuation-returning function |
| `bracket` | `Cont<E, A> bracket({...})` | Manage resource lifecycle with guaranteed cleanup |

## Transform Operators

Transform values on the success channel using pure functions.

| Method | Description |
|--------|-------------|
| `thenMap(f)` | Transform value with function `A → A2` |
| `thenMap0(f)` | Transform with zero-argument function `() → A2` |
| `thenMapWithEnv(f)` | Transform with `(E, A) → A2` |
| `thenMapWithEnv0(f)` | Transform with `E → A2` |
| `thenMapTo(value)` | Replace value with constant |

## Chain Operators (Do)

Chain continuations based on the previous result (monadic bind).

| Method | Description |
|--------|-------------|
| `thenDo(f)` | Chain with `A → Cont<E, A2>` |
| `thenDo0(f)` | Chain with `() → Cont<E, A2>` |
| `thenDoWithEnv(f)` | Chain with `(E, A) → Cont<E, A2>` |
| `thenDoWithEnv0(f)` | Chain with `E → Cont<E, A2>` |

## Tap Operators

Execute side effects while preserving the original value.

| Method | Description |
|--------|-------------|
| `thenTap(f)` | Side effect with `A → Cont<E, _>`, returns original `A` |
| `thenTap0(f)` | Side effect with `() → Cont<E, _>` |
| `thenTapWithEnv(f)` | Side effect with `(E, A) → Cont<E, _>` |
| `thenTapWithEnv0(f)` | Side effect with `E → Cont<E, _>` |

## Zip Operators

Run and combine results from two continuations.

| Method | Description |
|--------|-------------|
| `thenZip(f, combine)` | Chain `A → Cont<E, A2>` and combine with `(A, A2) → A3` |
| `thenZip0(f, combine)` | Chain `() → Cont<E, A2>` and combine results |
| `thenZipWithEnv(f, combine)` | Chain `(E, A) → Cont<E, A2>` and combine |
| `thenZipWithEnv0(f, combine)` | Chain `E → Cont<E, A2>` and combine |

## Fork Operators

Fire-and-forget side effects (don't wait for completion).

| Method | Description |
|--------|-------------|
| `thenFork(f)` | Fire-and-forget with `A → Cont<E, _>` |
| `thenFork0(f)` | Fire-and-forget with `() → Cont<E, _>` |
| `thenForkWithEnv(f)` | Fire-and-forget with `(E, A) → Cont<E, _>` |
| `thenForkWithEnv0(f)` | Fire-and-forget with `E → Cont<E, _>` |

## Conditional Operators (If)

Filter or validate values based on predicates.

| Method | Description |
|--------|-------------|
| `thenIf(predicate)` | Succeed only if `A → bool` is true, else terminate |
| `thenIf0(predicate)` | Succeed only if `() → bool` is true |
| `thenIfWithEnv(predicate)` | Succeed only if `(E, A) → bool` is true |
| `thenIfWithEnv0(predicate)` | Succeed only if `E → bool` is true |

## Loop Operators (While/Until)

Repeatedly execute a continuation based on predicates.

| Method | Description |
|--------|-------------|
| `thenWhile(predicate)` | Loop while `A → bool` is true |
| `thenWhile0(predicate)` | Loop while `() → bool` is true |
| `thenWhileWithEnv(predicate)` | Loop while `(E, A) → bool` is true |
| `thenWhileWithEnv0(predicate)` | Loop while `E → bool` is true |
| `thenUntil(predicate)` | Loop until `A → bool` is true (inverse of while) |
| `thenUntil0(predicate)` | Loop until `() → bool` is true |
| `thenUntilWithEnv(predicate)` | Loop until `(E, A) → bool` is true |
| `thenUntilWithEnv0(predicate)` | Loop until `E → bool` is true |
| `forever()` | Loop indefinitely, returns `Cont<E, Never>` |

## Abort Operators

Force termination with computed errors.

| Method | Description |
|--------|-------------|
| `abort(f)` | Terminate with `A → List<ContError>` |
| `abort0(f)` | Terminate with `() → List<ContError>` |
| `abortWithEnv(f)` | Terminate with `(E, A) → List<ContError>` |
| `abortWithEnv0(f)` | Terminate with `E → List<ContError>` |
| `abortWith(errors)` | Terminate with fixed error list |

## Error Operators (elseDo)

Recover from termination by providing fallback continuations.

| Method | Description |
|--------|-------------|
| `elseDo(f)` | Recover with `List<ContError> → Cont<E, A>` |
| `elseDo0(f)` | Recover with `() → Cont<E, A>` |
| `elseDoWithEnv(f)` | Recover with `(E, List<ContError>) → Cont<E, A>` |
| `elseDoWithEnv0(f)` | Recover with `E → Cont<E, A>` |

## Error Map Operators

Transform errors while staying on the termination channel.

| Method | Description |
|--------|-------------|
| `elseMap(f)` | Transform errors with `List<ContError> → List<ContError>` |
| `elseMap0(f)` | Replace errors with `() → List<ContError>` |
| `elseMapWithEnv(f)` | Transform errors with `(E, List<ContError>) → List<ContError>` |
| `elseMapWithEnv0(f)` | Replace errors with `E → List<ContError>` |
| `elseMapTo(errors)` | Replace errors with fixed list |

## Error Tap Operators

Execute side effects on termination while preserving errors.

| Method | Description |
|--------|-------------|
| `elseTap(f)` | Side effect with `List<ContError> → Cont<E, _>` |
| `elseTap0(f)` | Side effect with `() → Cont<E, _>` |
| `elseTapWithEnv(f)` | Side effect with `(E, List<ContError>) → Cont<E, _>` |
| `elseTapWithEnv0(f)` | Side effect with `E → Cont<E, _>` |

## Error Zip Operators

Run fallback and combine errors from both attempts.

| Method | Description |
|--------|-------------|
| `elseZip(f)` | Run `List<ContError> → Cont<E, A>` and merge errors if both fail |
| `elseZip0(f)` | Run `() → Cont<E, A>` and merge errors if both fail |
| `elseZipWithEnv(f)` | Run `(E, List<ContError>) → Cont<E, A>` and merge errors |
| `elseZipWithEnv0(f)` | Run `E → Cont<E, A>` and merge errors |

## Error Fork Operators

Fire-and-forget error handlers.

| Method | Description |
|--------|-------------|
| `elseFork(f)` | Fire-and-forget with `List<ContError> → Cont<E, _>` |
| `elseFork0(f)` | Fire-and-forget with `() → Cont<E, _>` |
| `elseForkWithEnv(f)` | Fire-and-forget with `(E, List<ContError>) → Cont<E, _>` |
| `elseForkWithEnv0(f)` | Fire-and-forget with `E → Cont<E, _>` |

## Error Conditional Operators

Conditionally recover based on error predicates.

| Method | Description |
|--------|-------------|
| `elseIf(predicate, value)` | Recover with `value` if `List<ContError> → bool` is true |
| `elseIf0(predicate, value)` | Recover with `value` if `() → bool` is true |
| `elseIfWithEnv(predicate, value)` | Recover with `value` if `(E, List<ContError>) → bool` is true |
| `elseIfWithEnv0(predicate, value)` | Recover with `value` if `E → bool` is true |

## Error Loop Operators

Retry on termination based on error predicates.

| Method | Description |
|--------|-------------|
| `elseWhile(predicate)` | Retry while `List<ContError> → bool` is true |
| `elseWhile0(predicate)` | Retry while `() → bool` is true |
| `elseWhileWithEnv(predicate)` | Retry while `(E, List<ContError>) → bool` is true |
| `elseWhileWithEnv0(predicate)` | Retry while `E → bool` is true |
| `elseUntil(predicate)` | Retry until `List<ContError> → bool` is true |
| `elseUntil0(predicate)` | Retry until `() → bool` is true |
| `elseUntilWithEnv(predicate)` | Retry until `(E, List<ContError>) → bool` is true |
| `elseUntilWithEnv0(predicate)` | Retry until `E → bool` is true |

## Recovery Operators

Convenience operators for error recovery.

| Method | Description |
|--------|-------------|
| `recover(f)` | Recover with `List<ContError> → A` |
| `recover0(f)` | Recover with `() → A` |
| `recoverWithEnv(f)` | Recover with `(E, List<ContError>) → A` |
| `recoverWithEnv0(f)` | Recover with `E → A` |
| `recoverWith(value)` | Recover with constant value |

## Merge Operators

Run multiple continuations and combine their results.

| Method | Description |
|--------|-------------|
| `Cont.both(left, right, combine, policy)` | Run two continuations and combine results |
| `and(right, combine, policy)` | Instance method for `both` |
| `Cont.all(list, policy)` | Run list of continuations and collect results |

**Policies for both/all:**
- `ContBothPolicy.sequence()` - Run sequentially, stop on first failure
- `ContBothPolicy.mergeWhenAll()` - Run in parallel, wait for all, combine all errors
- `ContBothPolicy.quitFast()` - Run in parallel, quit on first failure

## Race Operators

Race multiple continuations for first success.

| Method | Description |
|--------|-------------|
| `Cont.either(left, right, policy)` | Race two continuations, return first success |
| `or(right, policy)` | Instance method for `either` |
| `Cont.any(list, policy)` | Race list of continuations, return first success |

**Policies for either/any:**
- `ContEitherPolicy.sequence()` - Try sequentially until one succeeds
- `ContEitherPolicy.mergeWhenAll(combine)` - Run in parallel, combine multiple successes
- `ContEitherPolicy.quitFast()` - Run in parallel, quit on first success

## Environment Operators

Manage environment threading and transformation.

| Method | Description |
|--------|-------------|
| `local(f)` | Transform environment with `E2 → E` before passing down |
| `local0(f)` | Provide environment from `() → E` |
| `scope(value)` | Replace environment with fixed value |
| `injectInto(cont)` | Inject value as environment for another continuation |
| `injectedBy(cont)` | Receive environment from another continuation's value |

## Execution Methods

Execute continuations and handle results.

| Method | Return Type | Description |
|--------|-------------|-------------|
| `run(env, {onPanic, onElse, onThen})` | `ContCancelToken` | Execute with callbacks for success/error, returns cancellation token |
| `ff(env, {onPanic})` | `void` | Fire-and-forget execution (no result callbacks, no cancellation) |
| `trap(env, {isCancelled, onPanic, onElse})` | `ContCancelToken` | Execute `Cont<E, Never>` with only error handler |

## Decorator Operator

Transform execution behavior.

| Method | Description |
|--------|-------------|
| `decor(f)` | Natural transformation over the run function |

## Extension Methods

Special operations on specific continuation types.

| Method | Applies To | Description |
|--------|-----------|-------------|
| `flatten()` | `Cont<E, Cont<E, A>>` | Flatten nested continuation structure |
| `absurd<A>()` | `Cont<E, Never>` | Convert never-producing continuation to any type |
| `trap(env, ...)` | `Cont<E, Never>` | Execute with only error handler |

## Supporting Types

### ContError

| Method | Description |
|--------|-------------|
| `ContError.withStackTrace(error, st)` | Create with existing stack trace |
| `ContError.withNoStackTrace(error)` | Create with empty stack trace |
| `ContError.capture(error)` | Create and capture current stack trace |

### ContCancelToken

| Method | Description |
|--------|-------------|
| `cancel()` | Request cancellation |
| `isCancelled()` | Check if cancelled |

### ContObserver

| Method | Description |
|--------|-------------|
| `onThen(value)` | Emit success value (idempotent, call once) |
| `onElse(errors)` | Emit termination errors (idempotent, call once) |

### ContRuntime

| Method | Description |
|--------|-------------|
| `env()` | Access current environment |
| `isCancelled()` | Check if execution was cancelled |
| `onPanic` | Access panic handler |

## Variant Patterns

Most operators follow consistent naming patterns for variants:

- **Base form**: `thenDo(f)` - Takes value parameter
- **0 form**: `thenDo0(f)` - Ignores value, zero-argument function
- **WithEnv form**: `thenDoWithEnv(f)` - Takes environment and value
- **WithEnv0 form**: `thenDoWithEnv0(f)` - Takes only environment

This pattern applies to:
- All `then*` operators (Do, Tap, Zip, Fork, If, While, Until, Map)
- All `else*` operators (Do, Map, Tap, Zip, Fork, If, While, Until)
- `abort*` operators
- `recover*` operators

---

## Quick Reference by Use Case

### Creating Continuations
- Simple value: `Cont.of(value)`
- Terminated: `Cont.stop(errors)`
- Custom: `Cont.fromRun((runtime, observer) => ...)`
- Deferred: `Cont.fromDeferred(() => ...)`
- Resource: `Cont.bracket(acquire:, use:, release:)`

### Transforming Values
- Map: `cont.thenMap(f)`
- Replace: `cont.thenMapTo(value)`
- With env: `cont.thenMapWithEnv((env, value) => ...)`

### Chaining
- Success: `cont.thenDo(f)`
- Error recovery: `cont.elseDo(f)`
- Side effect: `cont.thenTap(f)` / `cont.elseTap(f)`
- Fire-and-forget: `cont.thenFork(f)` / `cont.elseFork(f)`

### Conditionals
- Filter: `cont.thenIf(predicate)`
- Conditional recovery: `cont.elseIf(predicate, value)`
- Force terminate: `cont.abort(f)` / `cont.abortWith(errors)`

### Loops
- While: `cont.thenWhile(predicate)`
- Until: `cont.thenUntil(predicate)`
- Retry: `cont.elseWhile(predicate)` / `cont.elseUntil(predicate)`
- Forever: `cont.forever()`

### Parallel/Racing
- All succeed: `Cont.all(conts, policy)` / `left.and(right, combine, policy)`
- First success: `Cont.any(conts, policy)` / `left.or(right, policy)`

### Environment
- Access: `Cont.ask<E>()`
- Scope: `cont.scope(env)`
- Transform: `cont.local(f)`
- Inject: `provider.injectInto(operation)` / `operation.injectedBy(provider)`

### Execution
- Normal: `cont.run(env, onThen:, onElse:)`
- Fire-and-forget: `cont.ff(env)`
- Never-producing: `cont.trap(env, onElse:)`

---

## See Also

- **[Introduction](01-introduction.md)** - Core concepts
- **[Complete Examples](07-examples.md)** - Real-world patterns
- **[Extending Jerelo](06-extending.md)** - Custom operators
