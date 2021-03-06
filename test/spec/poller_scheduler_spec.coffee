'use strict'

describe "PollerScheduler", ->
  dateTime = "2010-01-01T18:00:00.000Z"
  initializeModule()
  subject = {}
  $rootScope = {}
  $q = {}
  $timeout = {}
  sandbox = {}
  jobs = []
  job1 =
    name: "Job1",
    priority: 2,
    run: ( -> true),
    interval: moment.duration(seconds: 30),
    timeout: moment.duration(seconds: 20)

  chainedJob = {}

  job2 =
    name: "Job2",
    priority: 3,
    run: ( -> true),
    interval: moment.duration(seconds: 30),
    timeout: moment.duration(seconds: 20)

  job3 = _.extend({}, job2, {
      name: "Job3",
      priority: 8
    })

  job4 = _.extend({}, job2, {
    name: "Job4",
    priority: 1
  })

  job5 = _.extend({}, job2, {
    name: "Job5",
    priority: 4
  })

  spyOnJob = (job) ->
    job.spy = sandbox.spy()
    job.run = ->
      job.spy()
      job.promise = $q.defer()
      job.promise.promise

  before inject (PollerScheduler, _$q_, _$timeout_, _$rootScope_) ->
    localStorage.clear()
    subject = PollerScheduler
    sandbox = sinon.sandbox.create()
    sandbox.useFakeTimers(moment(dateTime).unix() * 1000)
    $q = _$q_
    $timeout = _$timeout_
    $rootScope = _$rootScope_
    jobs = [job1, job2]
    spyOnJob(job1)
    spyOnJob(job2)

  afterEach ->
    subject.stop()
    $timeout.verifyNoPendingTasks()
    subject.clearJobs()
    sandbox.restore()
    localStorage.clear()

  configure = ->
    for jobDefinition in jobs
      subject.addJob(jobDefinition)

  configureChainedJob = ->
    subject.chainJob(chainedJob)

  startJobs = ->
    configure()
    subject.start()

  describe "start", ->
    describe "there are two jobs", ->
      it "executes both jobs immediately", ->
        startJobs()
        expect( job1.spy ).toHaveBeenCalledOnce()
        expect( job2.spy ).toHaveBeenCalledOnce()
        job2.promise.resolve("done")
        job1.promise.resolve("done")
        $rootScope.$digest()
        $timeout.flush()

      it "does not execute both jobs a second time", ->
        startJobs()
        job1.promise.resolve("Done")
        job2.promise.resolve("Done")
        $timeout.flush()
        $timeout.flush()
        expect( job1.spy ).toHaveBeenCalledOnce()
        expect( job2.spy ).toHaveBeenCalledOnce()

      it "executes both jobs a second time when time advances", ->
        startJobs()
        job1.promise.resolve("Done")
        job2.promise.resolve("Done")
        $rootScope.$digest()
        sandbox.clock.now = (moment('2010-01-01T18:00:40.000Z').unix() * 1000)
        $timeout.flush()
        expect( job1.spy ).toHaveBeenCalledTwice()
        expect( job2.spy ).toHaveBeenCalledTwice()
        $rootScope.$digest()
        subject.stop()
        $timeout.flush()

      it "notifies about start, success, failure, finally", ->
        successSpy = sandbox.spy()
        failSpy = sandbox.spy()
        startSpy = sandbox.spy()
        finishSpy = sandbox.spy()
        finish2Spy = sandbox.spy()
        scope = $rootScope.$new()
        cbForSpy = (spy) ->
          (event, args...) ->
            spy(args...)

        configure()
        subject.whenSucceeded 'Job1', scope, cbForSpy(successSpy)
        subject.whenFailed 'Job2', scope,  cbForSpy(failSpy)
        subject.whenStarted 'Job1', scope,  cbForSpy(startSpy)
        subject.whenFinished 'Job1', scope,  cbForSpy(finishSpy)
        subject.whenFinished 'Job2', scope,  cbForSpy(finish2Spy)
        subject.start()

        $rootScope.$digest()
        expect( startSpy ).toHaveBeenCalled()
        job1.promise.resolve(["Finished","Successfully"])
        $rootScope.$digest()
        expect( successSpy ).toHaveBeenCalledWith(["Finished", "Successfully"])
        expect( finishSpy ).toHaveBeenCalled()

        job2.promise.reject("Failed")
        $rootScope.$digest()
        expect( failSpy ).toHaveBeenCalledWith("Failed")
        expect( finish2Spy ).toHaveBeenCalled()

        subject.stop()
        $timeout.flush()

  describe "#onNextRunOf", ->
    it "resolves the promise when the job runs", ->
      startJobs()
      successSpy = sandbox.spy()
      subject.onNextRunOf('Job1').then(successSpy)
      job1.promise.resolve(["Item1","Item2"])
      $rootScope.$digest()
      expect( successSpy ).toHaveBeenCalledWith(["Item1","Item2"])
      subject.stop()
      $timeout.flush()

  describe '#runNow', ->
    it "runs the job immediately", ->
      startJobs()
      job1.promise.resolve('done')
      job2.promise.resolve('done')
      $rootScope.$digest()
      $timeout.flush()
      expect( job1.spy ).toHaveBeenCalledOnce()
      subject.runNow('Job1')
      expect( job1.spy ).toHaveBeenCalledTwice()
      expect( job2.spy ).toHaveBeenCalledOnce()
      subject.stop()
      $timeout.flush()

  describe "there are 5 jobs", ->
    before ->
      spyOnJob(job3)
      spyOnJob(job4)
      spyOnJob(job5)
      jobs = [job1,job2,job3,job4,job5]
      startJobs()

    it "only starts 4 of them", ->
      expect(job1.spy).toHaveBeenCalledOnce()
      expect(job2.spy).toHaveBeenCalledOnce()
      expect(job4.spy).toHaveBeenCalledOnce()
      expect(job5.spy).toHaveBeenCalledOnce()
      expect(job3.spy).not.toHaveBeenCalledOnce()
      subject.stop()
      $timeout.flush()

    it "starts the 5th one when one job finishes", ->
      job1.promise.resolve("Done")
      $rootScope.$digest()
      expect(job3.spy).toHaveBeenCalledOnce()
      subject.stop()
      $timeout.flush()

  describe "chaining jobs", ->
    before ->
      chainedJob = {
        name: "ChainJob"
        priority: 2
        timeout: moment.duration(seconds: 25)
        chainTo: 'Job1'
      }
      spyOnJob(chainedJob)
      spyOnJob(job1)
      subject.addJob(job1)
      subject.chainJob(chainedJob)
      subject.start()

    it "calls the chained job when the first job completes successfully", ->
      expect(job1.spy).toHaveBeenCalledOnce()
      expect(chainedJob.spy).not.toHaveBeenCalledOnce()
      job1.promise.resolve('Done')
      $rootScope.$digest()
      expect(chainedJob.spy).toHaveBeenCalledOnce()
      expect(localStorage.getItem("ls.poller.job.nextRun.ChainJob")).toEqual('2010-01-01T18:00:25.000Z')
      chainedJob.promise.resolve('Done')
      $rootScope.$digest()
      expect(localStorage.getItem("ls.poller.job.nextRun.ChainJob")).toBeNull()
      subject.stop()
      $timeout.flush()

    it "does not call the chained job if the first job does not complete successfully", ->
      job1.promise.reject('not done')
      $rootScope.$digest()
      expect(chainedJob.spy).not.toHaveBeenCalledOnce()
      subject.stop()
      $timeout.flush()


  describe '#setConcurrency', ->
    before ->
      subject.setConcurrency(1)
      startJobs()

    it "executes just 1 of them", ->
      expect(job1.spy).toHaveBeenCalled()
      expect(job2.spy).not.toHaveBeenCalled()
      subject.stop()
      $timeout.flush()

