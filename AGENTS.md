# PROJECT INSTRUCTIONS

## What this codebase is
This repo uses Jerelo `Cont<A>` for all async / async / effectful flows.

## Hard rules
- Do not introduce `Future` ever. Use Cont instead.
- Services expose methods returning `Cont<T>` only.
- Prefer `flatTap` for validation steps; 
- Prefer `forkTap` for update steps;
- Prefer `flatMapZipWith` for computations that depend on previous results and take two parameters. 
- Prefer `Cont.both/and/all` for concurrency.
- Prefer `Cont.raceForWinner` or `Cont.raceForLoser` for racing.
- Use `Cont.terminate` for errors. (never throw).
- Use 'orElse' operators for error handling.
- Every computation must either be of Cont type or a function that returns Cont type.
- Use `Cont.bracket` for resource management.
- Keep flows linear and readable; extract nested lambdas into separate functions whenever possible.


## How to verify changes
- Format: `dart format .`
- Analyze: `dart analyze`
- Test: `dart test`
