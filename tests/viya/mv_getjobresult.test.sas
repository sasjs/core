/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mp_assertdsobs.sas
  @li mv_createwebservice.sas
  @li mv_getjobresult.sas
  @li mv_jobflow.sas

**/

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