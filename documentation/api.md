
# Jerelo API

## Constructing

### Cont.fromRun

### Cont.fromFutureComp

### Cont.fromDeferred

### Cont.of

### Cont.terminate

### Cont.empty

### Cont.raise


### Cont.withRef

### Ref.commit

## Transforming

### map
### map0
### mapTo


## Chaining

### flatMap
### flatMap0
### flatMapTo

### flatTap
### flatTap0
### flatTapTo

### flatMapZipWith
### flatMapZipWith0
### flatMapZipWithTo
### Cont.sequence

## Merging

### Cont.both
### and
### Cont.all

## Racing
### Cont.raceForWinner
### raceForWinnerWith
### Cont.raceForWinnerAll

### Cont.raceForLoser
### raceForLoserWith
### raceForLoserAll

### Cont.either
### or
### Cont.any

# Recovering
### catchTerminate
### catchTerminate0
### catchTerminateTo

### catchError
### catchError0
### catchErrorTo

### catchEmpty
### catchEmptyTo

### filter

## Scheduling

### subscribeOn

### observeOn
### observeChannelOn

## Extensions

### flatten

## Running

### run
### runWith


## ContObserver

### ContObserver constructor

### ContObserver.ignore

### onValue

### onTerminate

### copyUpdateOnTerminate

### copyUpdateOnValue


## ContError

### ContError constructor

### error

### stackTrace


## ContScheduler

### ContScheduler.fromSchedule

### ContScheduler.immediate

### ContScheduler.delayed

### ContScheduler.microtask

### schedule

## TestContScheduler

### TestContScheduler constructor

### asScheduler

### pendingCount

### isIdle

### flush