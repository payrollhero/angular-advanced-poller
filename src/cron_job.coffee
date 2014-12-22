'use strict'

angular.module('cron-ng').factory 'CronJob', (localStorageService, CronJobRunner) ->
  class CronJob

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
      @nextRun = moment(localStorageService.get("cron.job.nextRun.#{@name}") || new Date())
      this

    isOverdue: ->
      moment().isAfter(@nextRun) || moment().isSame(@nextRun)

    getTimeout: ->
      @timeout || @_intervalOr30Seconds()

    _intervalOr30Seconds: ->
      _.min [@interval, moment.duration(seconds:30)], (duration) ->
        duration.asMilliseconds()

    saveNextRun: ->
      @nextRun = moment().add(@getNextInterval())
      localStorageService.set("cron.job.nextRun.#{@name}", @nextRun.toISOString())
      this

    cancel: ->
      @runner.stop() if @runner?
      @runner = null
      @stop() if @stop?

    execute: ->
      @_endPreviousRunner()
      @saveNextRun()
      @runner = new CronJobRunner(this)
      @runner.run()

    _endPreviousRunner: ->
      if @runner && @runner.running
        console.debug("Runner for job #{job.name} is still running.")
        @runner.stop()
