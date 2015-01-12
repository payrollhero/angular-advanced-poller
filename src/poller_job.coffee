'use strict'

angular.module('angular-advanced-poller').factory 'PollerJob', (localStorageService) ->
  class PollerJob

    makeOverdue: ->
      @nextRun = moment()
      @_saveRuntime()
      this

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
