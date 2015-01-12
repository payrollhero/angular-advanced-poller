'use strict'

angular.module('angular-advanced-poller').factory 'ChainedPollerJob', (localStorageService, PollerJobRunner, PollerJob) ->
  class ChainedPollerJob extends PollerJob

    validate: ->
      throw "Job must have a name" unless @name
      throw "Job must have an integer priority" unless @priority
      throw "You must use 'run' to specify what to do" unless _.isFunction(@run)
      throw "You must provide a function to 'stop'" if @stop && !_.isFunction(@stop)
      throw "You must tell what job to run this after using 'chainTo'" unless @chainTo
      throw "Timeout must be a moment duration" unless moment.isDuration(@timeout)

    isOverdue: ->
      !@runner && @nextRun && ( moment().isAfter(@nextRun) || moment().isSame(@nextRun) )

    initialize: ->
      storedTime = localStorageService.get("poller.job.nextRun.#{@name}")
      @nextRun = moment(storedTime) if storedTime
      this

    getTimeout: ->
      @timeout

    saveNextIncrementalRun: ->
      # we always wait until we are called via chain.
      @cancelNextRun()

    execute: ->
      @_endPreviousRunner()
      @runner = new PollerJobRunner(this)
      @_setToRetryInTimeout()
      @runner.run().then (items) =>
        @retries = 0
        @cancelNextRun()
        items
      .finally =>
        @runner = null
        return
