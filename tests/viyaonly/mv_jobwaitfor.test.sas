/**
  @file
  @brief Testing mv_jobwaitfor macro
  @details Submits a job and waits for it with the uri in both accepted
    forms (plain job uri and state link), verifying the output dataset
    always carries the plain job uri and that no macro variables leak
    scope.

    The child job is created under the JES job's own user folder
    (rather than mcTestAppLoc) so the test is independent of the
    identity the test session runs as.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mf_getapploc.sas
  @li mf_getplatform.sas
  @li mv_createjob.sas
  @li mv_jobexecute.sas
  @li mv_jobwaitfor.sas

**/

/* create the child job under the deployed appLoc (derived from
   _program at runtime) so the test works whichever identity runs
   it and whichever appLoc it is deployed to - the appLoc folder is
   always writable by the test session, since the deploy itself
   created it */
%let testloc=%mf_getapploc(&_program)/tests/mv_jobwaitfor_test;

filename testprog temp;
data _null_;
  file testprog;
  put 'data;run;';
run;
%mv_createjob(path=&testloc,name=waitjob,code=testprog)

/**
  * Test Case 1 - wait with the plain job uri (no /state suffix)
  */
%mv_jobexecute(
  path=&testloc,
  name=waitjob,
  outds=work.info
)

/* keep only the state link, then strip the /state suffix - this
   submits the plain job uri to mv_jobwaitfor */
data work.plainuri;
  set work.info;
  where method='GET' and rel='state';
  uri=substr(uri,1,length(uri)-6);
run;

%mp_assertscope(SNAPSHOT)
%mv_jobwaitfor(ALL,inds=work.plainuri,outds=work.jobstates1)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(%sysfunc(attrn(%sysfunc(open(work.jobstates1)),NOBS))=1),
  desc=mv_jobwaitfor completed the job from a plain uri
)

data _null_;
  set work.jobstates1;
  call symputx('goturi',uri);
run;

%mp_assert(
  iftrue=(%symexist(goturi) and %length(&goturi)=55),
  desc=outds uri is the plain 55-char job uri
)

/**
  * Test Case 2 - wait with the state link (with /state suffix)
  */
%mv_jobexecute(
  path=&testloc,
  name=waitjob,
  outds=work.info2
)

/* this time pass the state link as-is (with the /state suffix) */
data work.statelink;
  set work.info2;
  where method='GET' and rel='state';
run;

%mp_assertscope(SNAPSHOT)
%mv_jobwaitfor(ALL,inds=work.statelink,outds=work.jobstates2)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(%sysfunc(attrn(%sysfunc(open(work.jobstates2)),NOBS))=1),
  desc=mv_jobwaitfor completed the job from a state link
)

data _null_;
  set work.jobstates2;
  call symputx('goturi2',uri);
run;

%mp_assert(
  iftrue=(%symexist(goturi2) and %length(&goturi2)=55),
  desc=outds uri from state link is also the plain 55-char job uri
)
