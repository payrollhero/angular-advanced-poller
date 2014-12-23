cron.ng
=======

![build status](https://circleci.com/gh/payrollhero/cron.ng.png?circle-token=:circle-token)

Promise based stateful angular scheduler.  Cron.Ng.

## Installation

### Bower
Call the following command on your command line:

```sh
bower install --save angular-indexed-db
```

### Manual

- Download either the minified or unminified version from dist.
- Include it in your project

## Dependencies

Cron.Ng relies upon the LocalStorageModule to store the runtimes of the cron jobs.
It also uses momentjs and underscore.

## Usage

Add "cron.ng" to your angular app's dependencies.
Inject the ```CronScheduler``` wherever you want to use it.
Add jobs using ```CronScheduler.addJob```
Start the scheduler by using ```CronScheduler.start```

### Example

```coffee
angular.module('myModule', ['cron.ng']).run (CronScheduler, $http) ->
  CronScheduler.addJob
    name: 'getChanges'
    priority: 1
    interval: moment.duration(seconds: 30)
    timeout: moment.duration(seconds: 25)
    run: $http.get("/changes")

   CronScheduler.start()
```

### Job Definitions
The cron scheduler addJob defines the task you wish to run.  Pass it the parameters of your job.

- name -> A unique name for your job
- priority -> An integer priority for this job
- interval -> Amount of time to wait between runs
- run -> Function to start this job ( MUST return a promise)
- timeout -> (optional) Timeout after which to cancel and reschedule this job
- randomOffset -> (optional) Provide a random offset of time to the interval.
- stop -> (optional) Provides a function which can stop processes begun by 'run'

```coffee
CronScheduler.addJob({
  name: 'uniqueName'
  priority: 1 # Must be integer priority
  run: $q.defer().promise # Must be a promise
  interval: moment.duration(seconds: 30) # Must be a moment duration
  timeout: moment.duration(seconds: 20) # Must be a moment duration
  randomOffset: moment.duration(seconds: 5) # Must be moment duration
})
```

### Concurrency
The scheduler has a configurable maximum concurrency.  The default is 4.
It will at maximum run this number of jobs at a time.  This is useful
For limiting polling mechanisms to a fixed number at app startup.

```coffee
CronScheduler.setConcurrency(3)
```

### Starting and Stopping
There are three methods to help you run your jobs.
- CronScheduler.start -> Starts all jobs.  They will be scheduled now if they have not been run before.
- CronScheduler.stop -> Stops future jobs.  If they provide a 'stop' they will be cancelled immediately.
- CronScheduler.runNow(name) -> Sets a named job to execute immediately.

### Job Events
The Cron Scheduler announces the completion of named jobs via $rootScope.$broadcast.
The 4 lifecycle events of a job have associated events.
- Start
- Success
- Failure
- Finish

You may listen to these events with the following methods:

```coffee
CronScheduler.whenStarted name, $scope, callback
CronScheduler.whenSucceeded name, $scope, callback
CronScheduler.whenFailed name, $scope, callback
CronScheduler.whenFinished name, $scope, callback
```
These events will broadcast at each time an interval run of the job is executed.

#### Promise based listening
If you simply want to wait on the very next execution of a job, use ```onNextRunOf```

Example:

```coffee
CronScheduler.onNextRunOf('updateSchedules').then (schedules) ->
  console.log('schedules updated!')
```

