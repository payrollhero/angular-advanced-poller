
/**
 @license $cronScheduler
 (c) 2014 Bram Whillock (bramski)
 License: BSD
 */
'use strict';
var dependencies;

dependencies = ['LocalStorageModule'];

angular.module('cron.ng', dependencies);

'use strict';
angular.module('cron.ng').factory('CronJob', function(localStorageService, CronJobRunner) {
  var CronJob;
  return CronJob = (function() {
    function CronJob() {}

    CronJob.prototype.validate = function() {
      if (!this.name) {
        throw "Job must have a name";
      }
      if (!this.priority) {
        throw "Job must have an integer priority";
      }
      if (!_.isFunction(this.run)) {
        throw "You must use 'run' to specify what to do";
      }
      if (this.stop && !_.isFunction(this.stop)) {
        throw "You must provide a function to 'stop'";
      }
      if (!moment.isDuration(this.interval)) {
        throw "Interval must be a moment duration";
      }
      if (this.timeout && !moment.isDuration(this.timeout)) {
        throw "Timeout must be a moment duration";
      }
      if (this.randomOffset && !moment.isDuration(this.randomOffset)) {
        throw "Random offset must be a duration";
      }
    };

    CronJob.prototype.getNextInterval = function() {
      if (this.randomOffset != null) {
        return this.interval.asMilliseconds() + Math.ceil(Math.random() * this.randomOffset.asMilliseconds());
      } else {
        return this.interval.asMilliseconds();
      }
    };

    CronJob.prototype.initialize = function() {
      this.nextRun = moment(localStorageService.get("cron.job.nextRun." + this.name) || new Date());
      return this;
    };

    CronJob.prototype.isOverdue = function() {
      return moment().isAfter(this.nextRun) || moment().isSame(this.nextRun);
    };

    CronJob.prototype.makeOverdue = function() {
      this.nextRun = moment();
      this._saveRuntime();
      return this;
    };

    CronJob.prototype.getTimeout = function() {
      return this.timeout || this._intervalOr30Seconds();
    };

    CronJob.prototype._intervalOr30Seconds = function() {
      return _.min([
        this.interval, moment.duration({
          seconds: 30
        })
      ], function(duration) {
        return duration.asMilliseconds();
      });
    };

    CronJob.prototype.saveNextRun = function() {
      this.nextRun = moment().add(this.getNextInterval());
      this._saveRuntime();
      return this;
    };

    CronJob.prototype._saveRuntime = function() {
      return localStorageService.set("cron.job.nextRun." + this.name, this.nextRun.toISOString());
    };

    CronJob.prototype.cancel = function() {
      if (this.runner != null) {
        this.runner.stop();
      }
      this.runner = null;
      if (this.stop != null) {
        return this.stop();
      }
    };

    CronJob.prototype.execute = function() {
      this._endPreviousRunner();
      this.saveNextRun();
      this.runner = new CronJobRunner(this);
      return this.runner.run();
    };

    CronJob.prototype._endPreviousRunner = function() {
      if (this.runner && this.runner.running) {
        console.debug("Runner for job " + job.name + " is still running.");
        return this.runner.stop();
      }
    };

    return CronJob;

  })();
});

'use strict';
var __slice = [].slice;

angular.module('cron.ng').factory('CronJobRunner', function($q, $timeout) {
  var CronJobRunner;
  CronJobRunner = (function() {
    function CronJobRunner(job) {
      this.job = job;
      this.running = true;
    }

    CronJobRunner.prototype.run = function() {
      var promise;
      console.debug("Running job " + this.job.name);
      this.promise = $q.defer();
      promise = this._run();
      this._scheduleTimeout();
      promise.then((function(_this) {
        return function() {
          var args, _ref;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return (_ref = _this.promise).resolve.apply(_ref, args);
        };
      })(this))["catch"]((function(_this) {
        return function() {
          var args, _ref;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return (_ref = _this.promise).reject.apply(_ref, args);
        };
      })(this))["finally"]((function(_this) {
        return function() {
          _this._cancelTimeout();
        };
      })(this));
      return this.promise.promise["finally"]((function(_this) {
        return function() {
          return _this.running = false;
        };
      })(this));
    };

    CronJobRunner.prototype.stop = function() {
      console.debug("Stopping job " + this.job.name);
      this._cancelTimeout();
      return this.promise.resolve('Stopped');
    };

    CronJobRunner.prototype._run = function() {
      var result;
      result = this.job.run();
      if (result && _.isFunction(result["finally"])) {
        return result;
      } else {
        return $q.when(result);
      }
    };

    CronJobRunner.prototype._timeout = function() {
      console.debug("Timed out job " + this.job.name);
      return this.promise.reject('TimedOut');
    };

    CronJobRunner.prototype._scheduleTimeout = function() {
      return this.timeoutPromise = $timeout((function(_this) {
        return function() {
          return _this.timeoutPromise = $timeout(_.bind(_this._timeout, _this), _this.job.getTimeout().asMilliseconds());
        };
      })(this), 0);
    };

    CronJobRunner.prototype._cancelTimeout = function() {
      if (this.timeoutPromise) {
        $timeout.cancel(this.timeoutPromise);
      }
      return this.timeoutPromise = null;
    };

    return CronJobRunner;

  })();
  return CronJobRunner;
});

'use strict';

/**
  @ngdoc service
  @name cron.ng.CronScheduler
  @service CronScheduler
  @description
    The CronScheduler is a promise based scheduleer.
    It allows you to schedule jobs for regular periodic runs based upon a schedule.  It has a few main features.
    * Has a configurable concurrency so that only so many jobs may run at the same time.  Jobs are scheduled based upon
      priority.
    * Saves state of the jobs using local storage so that window opens & closes won't cause your jobs to re-execute when the user
      opens your app.
    * Pre-empting.  You may tell the scheduler to run a job immediately by name.
    * Simple configuration of jobs.
 */
var __slice = [].slice;

angular.module('cron.ng').service('CronScheduler', function(CronJob, $timeout, $rootScope, $q) {
  var announceJobCompletion, announceJobFailure, announceJobFinished, announceJobStarted, calculateTimeToNextJob, closestJobTime, executeJobs, executeNextJobsOnQueue, executingJobs, executionPromise, findJob, finishJobAndRunNextJobOnQueue, jobFromDefinition, jobs, maximumConcurrency, minWaitTime, onJobFailure, onJobFinished, onJobStarted, onJobSuccess, organizeJobs, stopAllJobs;
  jobs = [];
  executingJobs = [];
  executionPromise = null;
  maximumConcurrency = 4;
  minWaitTime = 100;
  jobFromDefinition = function(definition) {
    var job;
    job = new CronJob;
    _.defaults(job, definition);
    job.initialize();
    return job;
  };
  finishJobAndRunNextJobOnQueue = function(job) {
    return function() {
      announceJobFinished(job);
      executingJobs = _(executingJobs).without(job);
      return executeNextJobsOnQueue();
    };
  };
  announceJobFinished = function(job) {
    return $rootScope.$broadcast("cron.ng.job." + job.name + ".finish");
  };
  announceJobStarted = function(job) {
    return $rootScope.$broadcast("cron.ng.job." + job.name + ".start");
  };
  announceJobCompletion = function(job) {
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return $rootScope.$broadcast.apply($rootScope, ["cron.ng.job." + job.name + ".success"].concat(__slice.call(args)));
    };
  };
  announceJobFailure = function(job) {
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return $rootScope.$broadcast.apply($rootScope, ["cron.ng.job." + job.name + ".failure"].concat(__slice.call(args)));
    };
  };
  onJobSuccess = function(scope, job, callback) {
    return scope.$on("cron.ng.job." + job.name + ".success", callback);
  };
  onJobFailure = function(scope, job, callback) {
    return scope.$on("cron.ng.job." + job.name + ".failure", callback);
  };
  onJobStarted = function(scope, job, callback) {
    return scope.$on("cron.ng.job." + job.name + ".start", callback);
  };
  onJobFinished = function(scope, job, callback) {
    return scope.$on("cron.ng.job." + job.name + ".finish", callback);
  };
  closestJobTime = function() {
    var now;
    now = moment();
    return _(jobs).chain().map(function(job) {
      return Math.abs((job.nextRun || now).diff(now));
    }).min().value();
  };
  calculateTimeToNextJob = function() {
    var jobTime;
    if (_(jobs).any(function(job) {
      return job.isOverdue();
    })) {
      return minWaitTime;
    }
    jobTime = closestJobTime();
    if (jobTime === Infinity) {
      jobTime = 0;
    }
    return _.max([minWaitTime, jobTime]);
  };
  executeNextJobsOnQueue = function() {
    var nextJob, readyJobs;
    if (!executionPromise) {
      return;
    }
    readyJobs = _(jobs).filter(function(job) {
      return job.isOverdue();
    });
    if (readyJobs.length > 0) {
      console.debug("" + readyJobs.length + " jobs are ready at " + (moment().toISOString()));
    }
    while (executingJobs.length < maximumConcurrency && readyJobs.length > 0) {
      nextJob = readyJobs.shift();
      executingJobs.push(nextJob);
      announceJobStarted(nextJob);
      nextJob.execute().then(announceJobCompletion(nextJob), announceJobFailure(nextJob))["finally"](finishJobAndRunNextJobOnQueue(nextJob));
    }
  };
  organizeJobs = function() {
    return jobs = _(jobs).sortBy('priority');
  };
  executeJobs = function() {
    executionPromise = $timeout(executeJobs, calculateTimeToNextJob());
    return executeNextJobsOnQueue();
  };
  stopAllJobs = function() {
    return _(executingJobs).invoke('cancel');
  };
  findJob = function(name) {
    var job;
    job = _(jobs).findWhere({
      name: name
    });
    if (!job) {
      throw "Job " + name + " is not a known job";
    }
    return job;
  };

  /*
    @ngdoc method
    @name CronScheduler.addJob
    @function
  
    @description Add a job to this scheduler.  Must be done before calling 'start'
    @example
      CronScheduler.addJob({
        name: "Job1",
        priority: 2,
        run: ( -> true),
        interval: moment.duration(seconds: 30),
        timeout: moment.duration(seconds: 20)
        randomOffset: moment.duration(seconds: 5)
      })
   */
  this.addJob = function(jobDefinition) {
    var cronJob;
    if (executionPromise) {
      throw "The cron scheduler is running.  Stop it before adding jobs.";
    }
    cronJob = jobFromDefinition(jobDefinition);
    cronJob.validate();
    jobs.push(cronJob);
  };

  /*
    @ngdoc method
    @name CronScheduler.onNextRunOf
    @function
  
    @description Returns a promise which is fulfilled when the next run of
      the named job completes.
   */
  this.onNextRunOf = function(name) {
    var $scope, job, nextUpdate;
    job = findJob(name);
    $scope = $rootScope.$new(true);
    nextUpdate = $q.defer();
    onJobSuccess($scope, job, function() {
      var args, event;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      return nextUpdate.resolve.apply(nextUpdate, args);
    });
    onJobFailure($scope, job, function() {
      var args, event;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      return nextUpdate.reject.apply(nextUpdate, args);
    });
    nextUpdate.promise["finally"](function() {
      return $scope.$destroy();
    });
    return nextUpdate.promise;
  };

  /*
    @ngdoc method
    @name CronScheduler.whenStarted
    @function
  
    @description Calls the callback each time the job starts.
   */
  this.whenStarted = function(name, $scope, callback) {
    var job;
    job = findJob(name);
    return onJobStarted($scope, job, callback);
  };

  /*
    @ngdoc method
    @name CronScheduler.whenSucceeded
    @function
  
    @description Calls the callback each time the job is successful.
   */
  this.whenSucceeded = function(name, $scope, callback) {
    var job;
    job = findJob(name);
    return onJobSuccess($scope, job, callback);
  };

  /*
    @ngdoc method
    @name CronScheduler.whenFailed
    @function
  
    @description Calls the callback each time the job fails.
   */
  this.whenFailed = function(name, $scope, callback) {
    var job;
    job = findJob(name);
    return onJobFailure($scope, job, callback);
  };

  /*
    @ngdoc method
    @name CronScheduler.whenFinished
    @function
  
    @description Calls the callback each time the job finishes.
   */
  this.whenFinished = function(name, $scope, callback) {
    var job;
    job = findJob(name);
    return onJobFinished($scope, job, callback);
  };

  /*
    @ngdoc method
    @name CronScheduler.runNow
    @function
  
    @description Schedule the named job to run immediately.  Running of the job is still
      based upon priority.  If higher priority jobs still need to be run, the running
      of this job may be delayed.
   */
  this.runNow = function(name) {
    var job;
    job = findJob(name);
    job.makeOverdue();
    executeNextJobsOnQueue();
  };

  /*
    @ngdoc method
    @name CronScheduler.start
    @function
  
    @description Start the cron scheduler.  Waiting jobs will run immediately.
   */
  this.start = function() {
    console.debug("Cron.Ng starting");
    organizeJobs();
    executeJobs();
    console.debug("Cron.Ng started");
  };

  /*
    @ngdoc method
    @name CronScheduler.stop
    @function
  
    @description Stop the cron scheduler.  Jobs which can be stopped will be stopped immediately.
   */
  this.stop = function() {
    console.debug("Cron.Ng stopping.");
    stopAllJobs();
    if (executionPromise) {
      $timeout.cancel(executionPromise);
    }
    executionPromise = null;
    if (!$rootScope.$$phase) {
      $rootScope.$digest();
    }
    console.debug("Cron.Ng stopped.");
  };

  /*
    @ngdoc method
    @name setConcurrency
    @function
  
    @description Set the maximum concurrency of the scheduler.  max [n] jobs will be run at the same time.
   */
  this.setConcurrency = function(concurrency) {
    maximumConcurrency = concurrency;
  };
});
