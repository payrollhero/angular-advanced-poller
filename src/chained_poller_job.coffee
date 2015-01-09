'use strict'

angular.module('angular-advanced-poller').factory 'ChainedPollerJob', (localStorageService, PollerJobRunner) ->
  class ChainedPollerJob

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

    makeOverdue: ->
      @nextRun = moment()
      @_saveRuntime()
      this

    getTimeout: ->
      @timeout

    _saveRuntime: ->
      localStorageService.set("poller.job.nextRun.#{@name}", @nextRun.toISOString())

    cancel: ->
      @runner.stop() if @runner?
      @runner = null
      @stop() if @stop?

    execute: ->
      @_endPreviousRunner()
      @runner = new PollerJobRunner(this)
      @runner.run().then (items) =>
        localStorageService.remove("poller.job.nextRun.#{@name}")
        items
      .finally =>
        @runner = null
        return

    _endPreviousRunner: ->
      if @runner && @runner.running
        console.debug("Runner for job #{@name} is still running.")
        @runner.stop()
