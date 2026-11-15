/**
  @file
  @brief Testing mv_createjob macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_getfoldermembers.sas

**/

%let path=&mcTestAppLoc/jobs;

filename ft15f001 temp;
data _null_;
  file ft15f001;
  put 'data work.createdbyjob;';
  put '  x=1;';
  put 'run;';
run;

/* the JSON libname engine publishes five globals per libref when it parses a
  REST response, and the libref numbers are fixed because each test runs in a
  fresh session.  They are listed so the comparison covers the macro's own
  variables. */
%mp_assertscope(SNAPSHOT)
%mv_createjob(path=&path, name=createjob)
%mp_assertscope(COMPARE,
  desc=mv_createjob does not leak scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
    MC1_JADP1LEN MC1_JADP2LEN MC1_JADP3LEN MC1_JADPNUM MC1_JADVLEN
    MC2_JADP1LEN MC2_JADP2LEN MC2_JADP3LEN MC2_JADPNUM MC2_JADVLEN
    MC3_JADP1LEN MC3_JADP2LEN MC3_JADP3LEN MC3_JADPNUM MC3_JADVLEN
    MC4_JADP1LEN MC4_JADP2LEN MC4_JADP3LEN MC4_JADPNUM MC4_JADVLEN,
  outds=work.test_results
)

%mv_getfoldermembers(root=&path, outds=work.jobmembers)

%mp_assert(
  iftrue=(%mf_nobs(work.jobmembers)=1),
  desc=Check the job definition was created in the target folder
)
