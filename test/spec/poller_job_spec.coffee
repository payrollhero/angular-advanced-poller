'use strict'

describe "PollerJob", ->
  dateTime = "2010-01-01 10:00:00"
  initializeModule()
  subject = {}
  params = {}
  $q = {}
  $rootScope = {}

  before inject (PollerJob, _$q_, _$rootScope_) ->
    subject = PollerJob
    @sinon = sinon.sandbox.create()
    @sinon.useFakeTimers(moment(dateTime).unix() * 1000)
    $q = _$q_
    $rootScope = _$rootScope_
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
    localStorage.setItem("ls.poller.job.nextRun.#{params.name}", time.toISOString())
    time

  getLocalStorageTime = ->
    localStorage.getItem("ls.poller.job.nextRun.#{params.name}")

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

    describe 'execute', ->
      it 'sets the next run when the job completes successfully', ->
        deferred = $q.defer()
        params.run = ->
          deferred.promise
        inst = make()
        expect(getLocalStorageTime()).toBeNull()
        inst.execute()
        expect(getLocalStorageTime()).toEqual('2010-01-01T18:00:20.000Z')
        expect(inst.isOverdue()).toBeFalsy()
        deferred.resolve("Success")
        $rootScope.$digest()
        expect(getLocalStorageTime())
        .toEqual(moment().add(seconds: 30).toISOString())

      it 'sets the jobs next run to be the timeout when it fails', ->
        deferred = $q.defer()
        params.run = ->
          deferred.promise
        inst = make()
        expect(getLocalStorageTime()).toBeNull()
        inst.execute()
        expect(getLocalStorageTime()).toEqual('2010-01-01T18:00:20.000Z')
        expect(inst.isOverdue()).toBeFalsy()
        deferred.reject('failed')
        $rootScope.$digest()
        expect(getLocalStorageTime()).toEqual('2010-01-01T18:00:20.000Z')
        expect(inst.isOverdue()).toBeFalsy()

      it 'only retries the job 5 times then sets it to the standard timeout', ->
        params.timeout = moment.duration(seconds: 5)
        params.run = ->
          inst.deferred = $q.defer()
          inst.deferred.promise
        inst = make()
        _.times 4, (n) ->
          inst.execute()
          inst.deferred.reject('failed')
          expect(getLocalStorageTime()).toEqual('2010-01-01T18:00:05.000Z')
        expect(getLocalStorageTime()).toEqual('2010-01-01T18:00:05.000Z')
        inst.execute()
        expect(getLocalStorageTime()).toEqual('2010-01-01T18:00:30.000Z')

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

    describe 'saveNextIncrementalRun', ->
      it 'saves a value to local storage the interval from now', ->
        make().saveNextIncrementalRun()
        expect(getLocalStorageTime())
        .toEqual(moment().add(seconds: 30).toISOString())

    describe "#getNextInterval", ->
      it "gives the interval in milliseconds", ->
        expect(make().getNextInterval()).toEqual(30000)

      it "adds a proper random interval when configured", ->
        @sinon.stub(Math, "random", -> 0.5)
        params.randomOffset = moment.duration(seconds: 10)
        expect(make().getNextInterval()).toEqual(35000)
