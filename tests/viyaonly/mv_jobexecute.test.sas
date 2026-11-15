/**
  @file
  @brief Testing mv_jobexecute macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_jobexecute.sas

**/

%let path=&mcTestAppLoc/jobs;

filename ft15f001 temp;
data _null_;
  file ft15f001;
  put 'data _null_;';
  put '  put "executed by mv_jobexecute";';
  put 'run;';
run;
%mv_createjob(path=&path, name=executejob)

%mp_assertscope(SNAPSHOT)
%mv_jobexecute(path=&path, name=executejob, outds=work.joblinks)
%mp_assertscope(COMPARE,
  desc=mv_jobexecute does not leak scope,
    ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADP4LEN MC0_JADPNUM
    MC0_JADVLEN MC6_JADP1LEN MC6_JADP2LEN MC6_JADP3LEN MC6_JADPNUM MC6_JADVLEN,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.joblinks)>0),
  desc=Check the execution returned a set of links
)

data _null_;
  set work.joblinks;
  if rel='state' then call symputx('stateuri',href,'l');
run;
%mp_assert(
  iftrue=(%length(&stateuri)>0),
  desc=Check a state uri was returned for the running job
)
