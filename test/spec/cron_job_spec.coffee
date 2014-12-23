'use strict'

describe "CronJob", ->
  dateTime = "2010-01-01 10:00:00"
  initializeModule()
  subject = {}
  params = {}

  before inject (CronJob, _$timeout_) ->
    subject = CronJob
    @sinon = sinon.sandbox.create()
    @sinon.useFakeTimers(moment(dateTime).unix() * 1000)
    params =
      name: "Foobar",
      priority: 1,
      run: ( -> true),
      interval: moment.duration(seconds: 30),
      timeout: moment.duration(seconds: 20)

  afterEach ->
    localStorage.clear()
    @sinon.restore()

  make = ->
    inst = new subject()
    _.defaults(inst, params)
    inst.validate()
    inst.initialize()
    inst

  setLocalStorageTime = (timeString) ->
    time = moment(timeString)
    localStorage.setItem("ls.cron.job.nextRun.#{params.name}", time.toISOString())
    time

  describe "#validate", ->
    it "throws nothing when valid", ->
      expect(make).not.toThrowError()

    it "throws when invalid", ->
      params.name = undefined
      expect(make).toThrow("Job must have a name")

  describe "there is a valid instance", ->
    describe 'initialize', ->
      it 'sets next run to now', ->
        expect(make().nextRun.toISOString()).toEqual(moment().toISOString())

      it 'sets it to the local storage value if available', ->
        time = setLocalStorageTime '2011-01-01 10:00:00'
        expect(make().nextRun.toISOString()).toEqual(time.toISOString())

    describe 'isOverdue', ->
      it 'is overdue when nothing is in local storage', ->
        expect(make().isOverdue()).toBeTruthy()

      it 'is overdue when local storage has time before now', ->
        setLocalStorageTime '2009-01-01 10:00:00'
        expect(make().isOverdue()).toBeTruthy()

      it 'is not overdue when local storage has time after now', ->
        setLocalStorageTime '2011-01-01 10:00:00'
        expect(make().isOverdue()).toBeFalsy()

    describe 'makeOverdue', ->
      it 'makes it overdue when it was not', ->
        setLocalStorageTime '2011-01-01 10:00:00'
        inst = make()
        expect(inst.isOverdue()).toBeFalsy()
        inst.makeOverdue()
        expect(inst.isOverdue()).toBeTruthy()

    describe 'getTimeout', ->
      it 'returns 20 seconds', ->
        expect(make().getTimeout().asSeconds()).toEqual(20)

      it 'returns 30 seconds when no timeout is set', ->
        delete params.timeout
        expect(make().getTimeout().asSeconds()).toEqual(30)

      it 'returns 20 when the interval is less than 30', ->
        delete params.timeout
        params.interval = moment.duration(seconds: 20)
        expect(make().getTimeout().asSeconds()).toEqual(20)

    describe 'saveNextRun', ->
      it 'saves a value to local storage the interval from now', ->
        make().saveNextRun()
        expect(localStorage.getItem("ls.cron.job.nextRun.#{params.name}"))
        .toEqual(moment().add(seconds: 30).toISOString())

    describe "#getNextInterval", ->
      it "gives the interval in milliseconds", ->
        expect(make().getNextInterval()).toEqual(30000)

      it "adds a proper random interval when configured", ->
        @sinon.stub(Math, "random", -> 0.5)
        params.randomOffset = moment.duration(seconds: 10)
        expect(make().getNextInterval()).toEqual(35000)
