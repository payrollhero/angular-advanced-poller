'use strict'

angular.module('angular-advanced-poller').factory 'IntervalPollerJob', (localStorageService, PollerJobRunner, PollerJob) ->
  class IntervalPollerJob extends PollerJob
    validate: ->
      throw "Job must have a name" unless @name
      throw "Job must have an integer priority" unless @priority
      throw "You must use 'run' to specify what to do" unless _.isFunction(@run)
      throw "You must provide a function to 'stop'" if @stop && !_.isFunction(@stop)
      throw "Interval must be a moment duration" unless moment.isDuration(@interval)
      throw "Timeout must be a moment duration" if @timeout && !moment.isDuration(@timeout)
      throw "Random offset must be a duration" if @randomOffset && !moment.isDuration(@randomOffset)

    getTimeout: ->
      @timeout || @_intervalOr30Seconds()

    _intervalOr30Seconds: ->
      _.min [@interval, moment.duration(seconds:30)], (duration) ->
        duration.asMilliseconds()

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
