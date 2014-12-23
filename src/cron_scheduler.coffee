'use strict'

###*
  @ngdoc service
  @name cron.ng.CronScheduler
  @service CronScheduler
  @description
    The CronScheduler is a promise based scheduleer.
    It allows you to schedule jobs for regular periodic runs based upon a schedule.  It has a few main features.
    * Has a configurable concurrency so that only so many jobs may run at the same time.  Jobs are scheduled based upon
      priority.
    * Saves state of the jobs using local storage so that window opens & closes won't cause your jobs to re-execute when the user
      opens your app.
    * Pre-empting.  You may tell the scheduler to run a job immediately by name.
    * Simple configuration of jobs.
###
angular.module('cron.ng').service 'CronScheduler', (CronJob, $timeout, $rootScope, $q) ->
  jobs = []
  executingJobs = []
  executionPromise = null
  maximumConcurrency = 4
  minWaitTime = 100

  jobFromDefinition = (definition) ->
    job = new CronJob
    _.defaults(job, definition)
    job.initialize()
    job

  finishJobAndRunNextJobOnQueue = (job) ->
    ->
      announceJobFinished(job)
      executingJobs = _(executingJobs).without(job)
      executeNextJobsOnQueue()

  announceJobFinished = (job) ->
    $rootScope.$broadcast("cron.ng.job.#{job.name}.finish")

  announceJobStarted = (job) ->
    $rootScope.$broadcast("cron.ng.job.#{job.name}.start")

  announceJobCompletion = (job) ->
    (args...) ->
      $rootScope.$broadcast("cron.ng.job.#{job.name}.success", args...)

  announceJobFailure = (job) ->
    (args...) ->
      $rootScope.$broadcast("cron.ng.job.#{job.name}.failure", args...)

  onJobSuccess = (scope, job, callback) ->
    scope.$on("cron.ng.job.#{job.name}.success", callback)

  onJobFailure = (scope, job, callback) ->
    scope.$on("cron.ng.job.#{job.name}.failure", callback)

  onJobStarted = (scope, job, callback) ->
    scope.$on("cron.ng.job.#{job.name}.start", callback)

  onJobFinished = (scope, job, callback) ->
    scope.$on("cron.ng.job.#{job.name}.finish", callback)

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

  findJob = (name) ->
    job = _(jobs).findWhere(name: name)
    unless job
      throw "Job #{name} is not a known job"
    job

  ###
    @ngdoc method
    @name CronScheduler.addJob
    @function

    @description Add a job to this scheduler.  Must be done before calling 'start'
    @example
      CronScheduler.addJob({
        name: "Job1",
        priority: 2,
        run: ( -> true),
        interval: moment.duration(seconds: 30),
        timeout: moment.duration(seconds: 20)
        randomOffset: moment.duration(seconds: 5)
      })
  ###
  @addJob = (jobDefinition) ->
    if executionPromise
      throw "The cron scheduler is running.  Stop it before adding jobs."
    cronJob = jobFromDefinition(jobDefinition)
    cronJob.validate()
    jobs.push cronJob
    return

  ###
    @ngdoc method
    @name CronScheduler.onNextRunOf
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
    @name CronScheduler.whenStarted
    @function

    @description Calls the callback each time the job starts.
  ###
  @whenStarted = (job, $scope, callback) ->
    job = findJob(name)
    onJobStarted $scope, job, callback

  ###
    @ngdoc method
    @name CronScheduler.whenSucceeded
    @function

    @description Calls the callback each time the job is successful.
  ###
  @whenSucceeded = (job, $scope, callback) ->
    job = findJob(name)
    onJobSuccess $scope, job, callback

  ###
    @ngdoc method
    @name CronScheduler.whenFailed
    @function

    @description Calls the callback each time the job fails.
  ###
  @whenFailed = (job, $scope, callback) ->
    job = findJob(name)
    onJobFailure $scope, job, callback

  ###
    @ngdoc method
    @name CronScheduler.whenFinished
    @function

    @description Calls the callback each time the job finishes.
  ###
  @whenFinished = (job, $scope, callback) ->
    job = findJob(name)
    onJobFinished $scope, job, callback

  ###
    @ngdoc method
    @name CronScheduler.runNow
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
    @name CronScheduler.start
    @function

    @description Start the cron scheduler.  Waiting jobs will run immediately.
  ###
  @start = ->
    console.debug("Cron.Ng starting")
    organizeJobs()
    executeJobs()
    console.debug("Cron.Ng started")
    return

  ###
    @ngdoc method
    @name CronScheduler.stop
    @function

    @description Stop the cron scheduler.  Jobs which can be stopped will be stopped immediately.
  ###
  @stop = ->
    console.debug("Cron.Ng stopping.")
    stopAllJobs()
    $timeout.cancel(executionPromise) if executionPromise
    executionPromise = null
    unless $rootScope.$$phase
      $rootScope.$digest() #Force a digest to clear the timeouts before returning.
    console.debug("Cron.Ng stopped.")
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

  return
