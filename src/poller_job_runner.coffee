'use strict'

angular.module('angular-advanced-poller')
  .factory 'PollerJobRunner', ($q, $timeout) ->

    class PollerJobRunner
      constructor: (job) ->
        @job = job
        @running = true

      run: ->
        console.debug("Running job #{@job.name}")
        @promise = $q.defer()
        promise = @_run()
        @_scheduleTimeout()
        promise.then (args...) =>
          @promise.resolve(args...)
        .catch (args...) =>
          @promise.reject(args...)
        .finally =>
          @_cancelTimeout()
          return
        @promise.promise.finally =>
          @running = false

      stop: ->
        console.debug("Stopping job #{@job.name}")
        @_cancelTimeout()
        @promise.resolve('Stopped')

      _run: ->
        result = @job.run()
        if result and _.isFunction( result.finally )
          result
        else
          return $q.when(result)

      _timeout: ->
        console.debug("Timed out job #{@job.name}")
        @promise.reject('TimedOut')

      _scheduleTimeout: ->
        #Wrap setting the timeout in a zero time callback to prevent this being fired prematurely
        @timeoutPromise = $timeout =>
          @timeoutPromise = $timeout(_.bind(@_timeout,this), @job.getTimeout().asMilliseconds())
        , 0

      _cancelTimeout: ->
        $timeout.cancel(@timeoutPromise) if @timeoutPromise
        @timeoutPromise = null

    return PollerJobRunner
