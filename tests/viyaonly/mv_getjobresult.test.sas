/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mv_createwebservice.sas
  @li mv_getjobresult.sas
  @li mv_jobflow.sas

**/

options mprint notes;

/**
  * Test Case 1
  */

/* create a service */
filename testref temp;
data _null_;
  file testref;
  put 'data test; set sashelp.class;run;';
  put '%webout(OPEN)';
  put '%webout(OBJ,test)';
  put '%webout(CLOSE)';
run;
%mv_createwebservice(
  path=&mcTestAppLoc/services/temp,
  code=testref,
  name=testsvc
)

/* trigger and wait for it to finish */
data work.inputjobs;
  _program="&mcTestAppLoc/services/temp/testsvc";
run;
%mv_jobflow(inds=work.inputjobs
  ,maxconcurrency=4
  ,outds=work.results
  ,outref=myjoblog
)
/* stream the log */
data _null_;
  infile myjoblog;
  input;
  put _infile_;
run;

/* fetch the uri */
data _null_;
  set work.results;
  call symputx('uri',uri);
  put (_all_)(=);
run;

/* now get the results */
%mv_getjobresult(uri=&uri
  ,result=WEBOUT_JSON
  ,outref=myweb
  ,outlib=myweblib
)
data _null_;
  infile myweb;
  input;
  putlog _infile_;
run;
data work.out;
  set myweblib.test;
  put (_all_)(=);
run;
%mp_assertdsobs(work.out,
  desc=Test1 - 19 obs from sashelp.class in service result,
  test=EQUALS 19,
  outds=work.test_results
)

/**
  * Test Case 2 - a binary webout
  *
  * A job that streams a file registers its result under the file's own name
  * (_webout.pdf and friends).  A dotted key cannot be named through result=,
  * so the macro has to find the member itself and copy the bytes back intact.
  */
filename testref2 temp;
data _null_;
  file testref2;
  put 'filename binref filesrvc parenturi="&SYS_JES_JOB_URI"';
  put "  name='_webout.pdf' contenttype='application/pdf';";
  put 'data _null_;';
  put '  file binref recfm=n;';
  put "  put 'GIF89a';";
  put 'run;';
run;
%mv_createwebservice(
  path=&mcTestAppLoc/services/temp,
  code=testref2,
  name=testsvcbin
)

data work.inputjobs2;
  _program="&mcTestAppLoc/services/temp/testsvcbin";
run;
%mv_jobflow(inds=work.inputjobs2
  ,maxconcurrency=1
  ,outds=work.results2
  ,outref=myjoblog2
)
data _null_;
  set work.results2;
  call symputx('uri2',uri);
run;

/* no result= on purpose - the caller cannot name a dotted member */
%mv_getjobresult(uri=&uri2, outref=mybin)
data _null_;
  infile mybin recfm=f lrecl=6 obs=1;
  input sig $6.;
  call symputx('isbin',ifn(sig='GIF89a',1,0),'l');
run;
%mp_assert(
  iftrue=(&isbin=1),
  desc=Test2 - binary webout is returned in full,
  outds=work.test_results
)
