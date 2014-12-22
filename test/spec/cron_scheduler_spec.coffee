'use strict'

describe "CronScheduler", ->
  dateTime = "2010-01-01 10:00:00"
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

  before inject (CronScheduler, _$q_, _$timeout_, _$rootScope_) ->
    localStorage.clear()
    subject = CronScheduler
    sandbox = sinon.sandbox.create()
    sandbox.useFakeTimers(moment(dateTime).unix() * 1000)
    $q = _$q_
    $timeout = _$timeout_
    $rootScope = _$rootScope_
    jobs = [job1, job2]
    spyOnJob(job1)
    spyOnJob(job2)
    spyOnJob(job3)
    spyOnJob(job4)
    spyOnJob(job5)

  afterEach ->
    subject.stop()
    $timeout.verifyNoPendingTasks()
    sandbox.restore()
    localStorage.clear()

  configure = ->
    for jobDefinition in jobs
      subject.addJob(jobDefinition)

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
        sandbox.useFakeTimers(moment('2010-01-01 10:00:40').unix() * 1000)
        $timeout.flush()
        expect( job1.spy ).toHaveBeenCalledTwice()
        expect( job2.spy ).toHaveBeenCalledTwice()
        $rootScope.$digest()
        $timeout.flush()

    describe "scope events", ->
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
        scope.$on("cron.ng.job.Job1.success", cbForSpy(successSpy))
        scope.$on("cron.ng.job.Job2.failure", cbForSpy(failSpy))
        scope.$on("cron.ng.job.Job1.start", cbForSpy(startSpy))
        scope.$on("cron.ng.job.Job1.finish", cbForSpy(finishSpy))
        scope.$on('cron.ng.job.Job2.finish', cbForSpy(finish2Spy))

        console.log("b4 start")
        startJobs()
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

    describe "there are 5 jobs", ->
      before ->
        jobs = [job1,job2,job3,job4,job5]
        startJobs()

      it "only starts 4 of them", ->
        expect(job1.spy).toHaveBeenCalledOnce()
        expect(job2.spy).toHaveBeenCalledOnce()
        expect(job4.spy).toHaveBeenCalledOnce()
        expect(job5.spy).toHaveBeenCalledOnce()
        expect(job3.spy).not.toHaveBeenCalledOnce()

      it "starts the 5th one when one job finishes", ->
        job1.promise.resolve("Done")
        $rootScope.$digest()
        expect(job3.spy).toHaveBeenCalledOnce()
