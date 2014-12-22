'use strict'

angular.module('cron-ng').service 'CronScheduler', (CronJob, $timeout, $rootScope) ->
  jobs = []
  executingJobs = []
  executionPromise = null
  maximumConcurrency = 4

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
      console.debug("Job #{job.name} finished successfully.")
      $rootScope.$broadcast("cron.ng.job.#{job.name}.success", args...)

  announceJobFailure = (job) ->
    (args...) ->
      console.debug("Job #{job.name} failed.")
      $rootScope.$broadcast("cron.ng.job.#{job.name}.failure", args...)

  executeNextJobsOnQueue = ->
    return unless executionPromise #shortcut out if we're stopped
    readyJobs = _(jobs).filter( (job) -> job.isOverdue())
    console.debug("#{readyJobs.length} jobs are ready")
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
    console.debug("Execute Jobs called")
    executionPromise = $timeout executeJobs, 100
    executeNextJobsOnQueue()

  stopAllJobs = ->
    _(executingJobs).invoke('cancel')

  @addJob = (jobDefinition) ->
    if executionPromise
      throw "The cron scheduler is running.  Stop it before adding jobs."
    cronJob = jobFromDefinition(jobDefinition)
    cronJob.validate()
    jobs.push cronJob

  @start = ->
    organizeJobs()
    console.debug("Cron-ng started")
    executeJobs()

  @stop = ->
    console.debug("Cron-ng stopping.")
    stopAllJobs()
    $timeout.cancel(executionPromise) if executionPromise
    executionPromise = null
    $rootScope.$digest() #Force a digest to clear the timeouts before returning.
    console.debug("Cron-ng stopped.")

  return
