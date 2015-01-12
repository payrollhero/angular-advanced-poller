angular-advanced-poller
=======

![build status](https://circleci.com/gh/payrollhero/angular-advanced-poller.png?circle-token=:circle-token)

Promise based stateful angular poller scheduler.

## Installation

### Bower
Call the following command on your command line:

```sh
bower install --save angular-advanced-poller
```

### Manual

- Download either the minified or unminified version from dist.
- Include it in your project

## Dependencies

Angular Advanced Poller relies upon the LocalStorageModule to store the runtimes of the jobs.
It also uses momentjs and underscore.

## Usage

Add "angular-advanced-poller" to your angular app's dependencies.
Inject the ```PollerScheduler``` wherever you want to use it.
Add jobs using ```PollerScheduler.addJob```
Start the scheduler by using ```PollerScheduler.start```

### Example

```coffee
angular.module('myModule', ['angular-advanced-poller']).run (PollerScheduler, $http) ->
  PollerScheduler.addJob
    name: 'getChanges'
    priority: 1
    interval: moment.duration(seconds: 30)
    timeout: moment.duration(seconds: 25)
    run: ( -> $http.get("/changes") )

  PollerScheduler.start()
```

### Job Definitions
The poller scheduler addJob defines the task you wish to run.  Pass it the parameters of your job.

- name -> A unique name for your job
- priority -> An integer priority for this job
- interval -> Amount of time to wait between runs
- run -> Function to start this job ( MUST return a promise)
- timeout -> (optional) Timeout after which to cancel and reschedule this job
- randomOffset -> (optional) Provide a random offset of time to the interval.
- stop -> (optional) Provides a function which can stop processes begun by 'run'

```coffee
PollerScheduler.addJob({
  name: 'uniqueName'
  priority: 1 # Must be integer priority
  run: $q.defer().promise # Must be a promise
  interval: moment.duration(seconds: 30) # Must be a moment duration
  timeout: moment.duration(seconds: 20) # Must be a moment duration
  randomOffset: moment.duration(seconds: 5) # Must be moment duration
  retry: 5 #Jobs are defaulted to retry 5 times, but you can set it per job
})
```

### Chained Jobs
Jobs can be chained to each other so that one job executes automatically when another finishes.
Adding a chained job is similar to a normal job with slightly different parameters

```coffee
PollerScheduler.chainJob({
  name: 'chainedJob'
  priority: 5 # Must be an integer
  run: $q.defer.promise # Must be a promise
  chainTo: 'otherJob' # 'name' of the other job
  timeout: moment.duration(seconds: 20) #Required timeout
  retry: 5 #Jobs are defaulted to retry 5 times, but you can set it per job
})
```
Chained jobs execute on successful completion of the job they are chained to.  When the chained job
is activated it is added to the execution list and scheduled in turn with the normal jobs.  When a chain
job completes successfully it will not be run again until the job it is chained to is run.

### Job timeout, retry, and wait time

The angular advanced poller uses the browser local storage to keep track of when every job should be run,
including chained jobs.  This makes it safe for app closure/restart/upgrade.
- a job is 'overdue' when the time in local storage is equal or greater to the current time
- 'overdue' jobs are scheduled for execution immediately and executed concurrently in priority order
- when a job is running it will be 'overdue' after the configured timeout (this is stored in local storage)
- if a job fails it will be retried after the configured 'timeout'
- once the maximum number of retries of a job are reached, it is scheduled again after the standard interval.

### Concurrency
The scheduler has a configurable maximum concurrency.  The default is 4.
It will at maximum run this number of jobs at a time.  This is useful
For limiting polling mechanisms to a fixed number at app startup.

```coffee
PollerScheduler.setConcurrency(3)
```

### Starting and Stopping
There are three methods to help you run your jobs.
- PollerScheduler.start -> Starts all jobs.  They will be scheduled now if they have not been run before.
- PollerScheduler.stop -> Stops future jobs.  If they provide a 'stop' they will be cancelled immediately.
- PollerScheduler.runNow(name) -> Sets a named job to execute immediately.

### Job Events
The Scheduler announces the completion of named jobs via $rootScope.$broadcast.
The 4 lifecycle events of a job have associated events.
- Start
- Success
- Failure
- Finish

You may listen to these events with the following methods:

```coffee
PollerScheduler.whenStarted name, $scope, callback
PollerScheduler.whenSucceeded name, $scope, callback
PollerScheduler.whenFailed name, $scope, callback
PollerScheduler.whenFinished name, $scope, callback
```
These events will broadcast at each time an interval run of the job is executed.

#### Promise based listening
If you simply want to wait on the very next execution of a job, use ```onNextRunOf```

Example:

```coffee
PollerScheduler.onNextRunOf('updateSchedules').then (schedules) ->
  console.log('schedules updated!')
```

