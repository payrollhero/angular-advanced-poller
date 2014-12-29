'use strict'

describe "PollerJobRunner", ->
  dateTime = "2010-01-01 10:00:00"
  initializeModule()
  subject = {}
  PollerJob = {}
  params = {}
  $q = {}
  $timeout = {}

  before inject (_PollerJob_, PollerJobRunner, _$q_, _$timeout_) ->
    subject = PollerJobRunner
    @sinon = sinon.sandbox.create()
    @sinon.useFakeTimers(moment(dateTime).unix() * 1000)
    PollerJob = _PollerJob_
    $q = _$q_
    $timeout = _$timeout_
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
    inst = new PollerJob()
    _.defaults(inst, params)
    inst.validate()
    inst.initialize()
    new subject(inst)

  describe 'run', ->
    describe 'when run returns in the allotted time', ->
      it 'runs with no errors', ->
        spy = @sinon.spy()
        catchSpy = @sinon.spy()
        params.run = ->
          spy()
          $q.when(true)
        make().run().catch(catchSpy)
        $timeout.flush()
        expect(spy).toHaveBeenCalled()
        expect(catchSpy).not.toHaveBeenCalled()
        $timeout.verifyNoPendingTasks()

    describe 'when run does not return in the allotted time', ->
      it 'throws a timeout', ->
        catchSpy = @sinon.spy()
        params.run = ->
          $q.defer().promise
        make().run().catch(catchSpy)
        $timeout.flush()
        $timeout.flush()
        expect(catchSpy).toHaveBeenCalledWith(
          "TimedOut"
        )
