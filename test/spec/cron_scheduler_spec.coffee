'use strict'

ddescribe "CronScheduler", ->
  dateTime = "2010-01-01 10:00:00"
  initializeModule()
  subject = {}
  CronJob = {}
  params = {}
  $q = {}
  $timeout = {}
  sandbox = {}
  jobs = []
  job1 =
    name: "Foobar",
    priority: 1,
    run: ( -> true),
    interval: moment.duration(seconds: 30),
    timeout: moment.duration(seconds: 20)

  job2 =
    name: "Smaug",
    priority: 2,
    run: ( -> true),
    interval: moment.duration(seconds: 30),
    timeout: moment.duration(seconds: 20)

  spyOnJob = (job) ->
    job.spy = sandbox.spy()
    job.promise = $q.defer()
    job.run = ->
      job.spy()
      job.promise.promise

  before inject (CronScheduler, _$q_, _$timeout_) ->
    localStorage.clear()
    subject = CronScheduler
    sandbox = sinon.sandbox.create()
    sandbox.useFakeTimers(moment(dateTime).unix() * 1000)
    $q = _$q_
    $timeout = _$timeout_
    jobs = [job1, job2]
    spyOnJob(job1)
    spyOnJob(job2)

  afterEach ->
    subject.stop()
    $timeout.flush()
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
    it "executes both jobs immediately", ->
      startJobs()
      expect( job1.spy ).toHaveBeenCalledOnce()
      expect( job2.spy ).toHaveBeenCalledOnce()
