/**
  @file
  @brief Testing mv_getjobstate macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_getjobstate.sas
  @li mv_jobexecute.sas

**/

%let path=&mcTestAppLoc/jobs;

filename ft15f001 temp;
data _null_;
  file ft15f001;
  put 'data _null_;';
  put '  put "executed to obtain a job uri";';
  put 'run;';
run;
%mv_createjob(path=&path, name=statejob)
%mv_jobexecute(path=&path, name=statejob, outds=work.joblinks)
data _null_;
  set work.joblinks;
  if rel='state' then call symputx('stateuri',href,'l');
run;

%mp_assertscope(SNAPSHOT)
%mv_getjobstate(uri=&stateuri, outds=work.jobstate)
%mp_assertscope(COMPARE,
  desc=mv_getjobstate does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.jobstate))=1),
  desc=Check the job state dataset was created
)
%mp_assert(
  iftrue=(%mf_nobs(work.jobstate)>0),
  desc=Check a job state row was returned
)
%mp_assert(
  iftrue=(%mf_existvar(work.jobstate,state)>0),
  desc=Check the dataset carries a state column
)
