'use strict'

###*
  @ngdoc service
  @name angular-advanced-poller.PollerScheduler
  @service PollerScheduler
  @description
    The PollerScheduler is a promise based scheduleer.
    It allows you to schedule jobs for regular periodic runs based upon a schedule.  It has a few main features.
    * Has a configurable concurrency so that only so many jobs may run at the same time.  Jobs are scheduled based upon
      priority.
    * Saves state of the jobs using local storage so that window opens & closes won't cause your jobs to re-execute when the user
      opens your app.
    * Pre-empting.  You may tell the scheduler to run a job immediately by name.
    * Simple configuration of jobs.
###
angular.module('angular-advanced-poller').service 'PollerScheduler', (IntervalPollerJob, ChainedPollerJob, $timeout, $rootScope, $q) ->
  jobs = []
  executingJobs = []
  executionPromise = null
  maximumConcurrency = 4
  minWaitTime = 100

  addJobFromDefinition = (definition, defClass) ->
    throw "A job of name #{definition.name} is already registered" if hasJob(definition.name)
    job = new defClass
    _.defaults(job, definition)
    job.initialize()
    job.validate()
    jobs.push job
    organizeJobs()
    job

  finishJobAndRunNextJobOnQueue = (job) ->
    ->
      announceJobFinished(job)
      executingJobs = _(executingJobs).without(job)
      executeNextJobsOnQueue()

  announceJobFinished = (job) ->
    $rootScope.$broadcast("poller.job.#{job.name}.finish")

  announceJobStarted = (job) ->
    $rootScope.$broadcast("poller.job.#{job.name}.start")

  announceJobCompletion = (job) ->
    (args...) ->
      $rootScope.$broadcast("poller.job.#{job.name}.success", args...)

  announceJobFailure = (job) ->
    (args...) ->
      $rootScope.$broadcast("poller.job.#{job.name}.failure", args...)

  onJobSuccess = (scope, job, callback) ->
    scope.$on("poller.job.#{job.name}.success", callback)

  onJobFailure = (scope, job, callback) ->
    scope.$on("poller.job.#{job.name}.failure", callback)

  onJobStarted = (scope, job, callback) ->
    scope.$on("poller.job.#{job.name}.start", callback)

  onJobFinished = (scope, job, callback) ->
    scope.$on("poller.job.#{job.name}.finish", callback)

  closestJobTime = ->
    now = moment()
    _(jobs).chain().map( (job) ->
      Math.abs((job.nextRun || now).diff(now))
    ).min().value()

  calculateTimeToNextJob = ->
    return minWaitTime if _(jobs).any( (job) -> job.isOverdue())
    jobTime = closestJobTime()
    jobTime = 0 if jobTime is Infinity
    _.max([minWaitTime, jobTime])

  executeNextJobsOnQueue = ->
    return unless executionPromise #shortcut out if we're stopped
    readyJobs = _(jobs).filter( (job) -> job.isOverdue())
    console.debug("#{readyJobs.length} jobs are ready at #{moment().toISOString()}") if readyJobs.length > 0
    while executingJobs.length < maximumConcurrency && readyJobs.length > 0
      nextJob = readyJobs.shift()
      executingJobs.push nextJob
      announceJobStarted(nextJob)
      nextJob.execute()
      .then(announceJobCompletion(nextJob), announceJobFailure(nextJob))
      .finally(finishJobAndRunNextJobOnQueue(nextJob))
    return

  organizeJobs = ->
    jobs = _(jobs).sortBy('priority')

  executeJobs = ->
    executionPromise = $timeout executeJobs, calculateTimeToNextJob()
    executeNextJobsOnQueue()

  stopAllJobs = ->
    _(executingJobs).invoke('cancel')

  hasJob = (name) ->
    _(jobs).findWhere(name: name)?

  findJob = (name) ->
    job = _(jobs).findWhere(name: name)
    unless job
      throw "Job #{name} is not a known job"
    job

  ###
    @ngdoc method
    @name PollerScheduler.addJob
    @function

    @description Add a job to this scheduler.  Must be done before calling 'start'
    @example
      PollerScheduler.addJob({
        name: "Job1",
        priority: 2,
        run: ( -> true),
        interval: moment.duration(seconds: 30),
        timeout: moment.duration(seconds: 20)
        randomOffset: moment.duration(seconds: 5)
      })
  ###
  @addJob = (jobDefinition) ->
    addJobFromDefinition(jobDefinition, IntervalPollerJob)
    return

  ###
    @ngdoc method
    @name PollerScheduler.chainJob
    @function

    @description Add a new job to the scheduler, chained to the success of another job.
                 This job will execute when the other job completes successfully.
    @example
      PollerScheduler.chainJob({
        name: "Job2",
        priority: 2,
        run: ( -> true),
        timeout: moment.duration(seconds: 20)
        chainTo: 'Job1'
      })
  ###
  @chainJob = (jobDefinition) ->
    job = addJobFromDefinition(jobDefinition, ChainedPollerJob)
    job.scope = $rootScope.$new()
    @whenSucceeded job.chainTo, job.scope, ->
      console.debug("Chained job #{job.name} will now execute")
      job.makeOverdue()


  ###
    @ngdoc method
    @name PollerScheduler.onNextRunOf
    @function

    @description Returns a promise which is fulfilled when the next run of
      the named job completes.
  ###
  @onNextRunOf = (name) ->
    job = findJob(name)

    $scope = $rootScope.$new true
    nextUpdate = $q.defer()
    onJobSuccess $scope, job, (event, args...) ->
      nextUpdate.resolve(args...)
    onJobFailure $scope, job, (event, args...) ->
      nextUpdate.reject(args...)
    nextUpdate.promise.finally ->
      $scope.$destroy()
    nextUpdate.promise

  ###
    @ngdoc method
    @name PollerScheduler.whenStarted
    @function

    @description Calls the callback each time the job starts.
  ###
  @whenStarted = (name, $scope, callback) ->
    job = findJob(name)
    onJobStarted $scope, job, callback

  ###
    @ngdoc method
    @name PollerScheduler.whenSucceeded
    @function

    @description Calls the callback each time the job is successful.
  ###
  @whenSucceeded = (name, $scope, callback) ->
    job = findJob(name)
    onJobSuccess $scope, job, callback

  ###
    @ngdoc method
    @name PollerScheduler.whenFailed
    @function

    @description Calls the callback each time the job fails.
  ###
  @whenFailed = (name, $scope, callback) ->
    job = findJob(name)
    onJobFailure $scope, job, callback

  ###
    @ngdoc method
    @name PollerScheduler.whenFinished
    @function

    @description Calls the callback each time the job finishes.
  ###
  @whenFinished = (name, $scope, callback) ->
    job = findJob(name)
    onJobFinished $scope, job, callback

  ###
    @ngdoc method
    @name PollerScheduler.runNow
    @function

    @description Schedule the named job to run immediately.  Running of the job is still
      based upon priority.  If higher priority jobs still need to be run, the running
      of this job may be delayed.
  ###
  @runNow = (name) ->
    job = findJob(name)
    job.makeOverdue()
    executeNextJobsOnQueue()
    return

  ###
    @ngdoc method
    @name PollerScheduler.start
    @function

    @description Start the scheduler.  Waiting jobs will run immediately.
  ###
  @start = ->
    console.debug("AdvancedPoller starting")
    organizeJobs()
    executeJobs()
    console.debug("AdvancedPoller started")
    return

  ###
    @ngdoc method
    @name PollerScheduler.stop
    @function

    @description Stop the scheduler.  Jobs which can be stopped will be stopped immediately.
  ###
  @stop = ->
    console.debug("AdvancedPoller stopping.")
    stopAllJobs()
    $timeout.cancel(executionPromise) if executionPromise
    executionPromise = null
    unless $rootScope.$$phase
      $rootScope.$digest() #Force a digest to clear the timeouts before returning.
    executingJobs = []
    console.debug("AdvancedPoller stopped.")
    return

  ###
    @ngdoc method
    @name setConcurrency
    @function

    @description Set the maximum concurrency of the scheduler.  max [n] jobs will be run at the same time.
  ###
  @setConcurrency = (concurrency) ->
    maximumConcurrency = concurrency
    return

  @clearJobs = ->
    throw "Must be stopped to clear jobs" if executionPromise?
    jobs = []
    return

  return
