'use strict'

angular.module('cron-ng')
  .factory 'CronJobRunner', ($q, $timeout) ->

    class CronJobRunner
      constructor: (job) ->
        @job = job

      run: ->
        console.log("Running job #{@job.name}")
        @promise = $q.defer()
        promise = @_run()
        @_scheduleTimeout()
        promise.then (args...) =>
          @promise.resolve(args...)
        .catch (args...) =>
          @promise.reject(args...)
        .finally =>
          @_cancelTimeout()
        @promise.promise

      cancel: ->
        console.log("Cancelling job #{@job.name}")
        @_cancelTimeout()
        @promise.resolve('Job Cancelled')

      _run: ->
        result = @job.run()
        if result and _.isFunction( result.finally )
          result
        else
          return $q.when(result)

      _timeout: ->
        @promise.reject("Timed out #{@job.name} after #{@job.getTimeout().seconds()} seconds")

      _scheduleTimeout: ->
        #Wrap setting the timeout in a zero time callback to prevent this being fired prematurely
        @timeoutPromise = $timeout =>
          @timeoutPromise = $timeout(_.bind(@_timeout,this), @job.getTimeout().asMilliseconds())
        , 0

      _cancelTimeout: ->
        $timeout.cancel(@timeoutPromise) if @timeoutPromise
        @timeoutPromise = null

    return CronJobRunner
