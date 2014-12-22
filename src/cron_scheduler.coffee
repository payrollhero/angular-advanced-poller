'use strict'

angular.module('cron-ng').service 'CronScheduler', (CronJob, $timeout) ->
  jobs = []
  executingJobs = []
  executionPromise = null
  maximumConcurrency = 4

  jobFromDefinition = (definition) ->
    job = new CronJob
    _.defaults(job, definition)
    job.initialize()
    job

  executeNextJobsOnQueue = ->
    readyJobs = _(jobs).filter( (job) -> job.isOverdue())
    console.log("#{readyJobs.length} jobs are ready")
    while executingJobs.length < maximumConcurrency && readyJobs.length > 0
      nextJob = readyJobs.shift()
      executingJobs.push nextJob
      nextJob.execute().finally ->
        executingJobs = _(executingJobs).without(nextJob)
        executeNextJobsOnQueue()

  organizeJobs = ->
    jobs = _(jobs).sortBy('priority')

  executeJobs = ->
    try
      executeNextJobsOnQueue()
    finally
      executionPromise = $timeout executeJobs, 100

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
    console.log("Cron-ng started")
    executeJobs()

  @stop = ->
    console.log("Cron-ng stopped.")
    stopAllJobs()
    $timeout.cancel(executionPromise) if executionPromise
    executionPromise = null

  return
