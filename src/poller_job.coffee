'use strict'

angular.module('angular-advanced-poller').factory 'PollerJob', (localStorageService, PollerJobRunner, $q) ->
  class PollerJob

    validate: ->
      throw "Job must have a name" unless @name
      throw "Job must have an integer priority" unless @priority
      throw "You must use 'run' to specify what to do" unless _.isFunction(@run)
      throw "You must provide a function to 'stop'" if @stop && !_.isFunction(@stop)
      throw "Interval must be a moment duration" unless moment.isDuration(@interval)
      throw "Timeout must be a moment duration" if @timeout && !moment.isDuration(@timeout)
      throw "Random offset must be a duration" if @randomOffset && !moment.isDuration(@randomOffset)

    getNextInterval: ->
      if @randomOffset?
        @interval.asMilliseconds() + Math.ceil(Math.random() * @randomOffset.asMilliseconds())
      else
        @interval.asMilliseconds()

    initialize: ->
      @nextRun = moment(localStorageService.get("poller.job.nextRun.#{@name}") || new Date())
      this

    isOverdue: ->
      !@runner && ( moment().isAfter(@nextRun) || moment().isSame(@nextRun) )

    makeOverdue: ->
      @nextRun = moment()
      @_saveRuntime()
      this

    getTimeout: ->
      @timeout || @_intervalOr30Seconds()

    _intervalOr30Seconds: ->
      _.min [@interval, moment.duration(seconds:30)], (duration) ->
        duration.asMilliseconds()

    saveNextIncrementalRun: ->
      @nextRun = moment().add(@getNextInterval())
      @_saveRuntime()
      this

    cancelNextRun: ->
      @nextRun = undefined
      localStorageService.remove("poller.job.nextRun.#{@name}")

    _saveRuntime: ->
      localStorageService.set("poller.job.nextRun.#{@name}", @nextRun.toISOString())

    cancel: ->
      @runner.stop() if @runner?
      @runner = null
      @stop() if @stop?

    execute: ->
      @_endPreviousRunner()
      @runner = new PollerJobRunner(this)
      @_setToRetryInTimeout()
      @runner.run().then (items) =>
        @retries = 0
        @saveNextIncrementalRun()
        return items
      .finally =>
        @runner = null
        return

    maxRetries: ->
      @retry || 5

    _setToRetryInTimeout: ->
      @retries ||= 0
      @retries++
      if @retries < @maxRetries()
        if @retries > 1
          console.debug("Job #{name} has been retried #{@retries} times.")
        @nextRun = moment().add(milliseconds: @getTimeout().asMilliseconds())
        @_saveRuntime()
      else
        console.debug("Job #{name} has been retried more than #{@maxRetries()} times.")
        @saveNextIncrementalRun()
        @retries = 0
        #we've reached the maximum retries.


    _endPreviousRunner: ->
      if @runner && @runner.running
        console.debug("Runner for job #{@name} is still running.")
        @runner.stop()
