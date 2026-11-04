/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mv_createwebservice.sas
  @li mv_getjobresult.sas
  @li mv_jobflow.sas

  @sasjslint {"ignoredMacros": ["mp_abort"]}
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
  * so the macro has to find the member itself.  The payload carries the bytes
  * a text-mode copy would damage - CR, LF and NUL - so the first nine bytes are
  * compared exactly.
  */
filename testref2 temp;
data _null_;
  file testref2;
  put 'filename binref filesrvc parenturi="&SYS_JES_JOB_URI"';
  put "  name='_webout.pdf' contenttype='application/pdf';";
  put 'data _null_;';
  put '  length payload $9;';
  put '  payload=cat(byte(71),byte(73),byte(70),byte(56),byte(57),byte(97)';
  put '    ,byte(13),byte(10),byte(0));';
  put '  file binref recfm=n;';
  put '  put payload $char9.;';
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
/* the first nine bytes are compared, which is also how DC's own download
  * test reads a binary payload: a text-mode copy would drop the NUL and
  * shift the rest, so the comparison fails rather than passing on a prefix */
data _null_;
  infile mybin recfm=f lrecl=9 obs=1;
  length sig $9 want $9;
  input sig $9.;
  want=cat(byte(71),byte(73),byte(70),byte(56),byte(57),byte(97)
    ,byte(13),byte(10),byte(0));
  call symputx('isbin',ifn(sig=want,1,0),'l');
run;
%mp_assert(
  iftrue=(&isbin=1),
  desc=Test2 - binary webout returned byte for byte (CR LF NUL intact),
  outds=work.test_results
)

/**
  * Test Case 3 - an aborted child still yields a parsable result
  *
  * mp_abort writes the transport envelope (>>weboutBEGIN<<) around the abort
  * object, because that is what the client frames the response with.  The JSON
  * engine knows nothing of it, so a libname over the raw artefact fails on line
  * one - for exactly the responses a caller reads to find out why a child
  * stopped.  The abort object is the result here, so parsing it is the test.
  */
filename testref3 temp;
data _null_;
  file testref3;
  put '%mp_abort(mac=test,msg=%str(deliberate abort from getjobresult test))';
run;
%mv_createwebservice(
  path=&mcTestAppLoc/services/temp,
  code=testref3,
  name=testsvcabort
)

data work.inputjobs3;
  _program="&mcTestAppLoc/services/temp/testsvcabort";
run;
%mv_jobflow(inds=work.inputjobs3
  ,maxconcurrency=1
  ,outds=work.results3
  ,outref=myjoblog3
)
data _null_;
  set work.results3;
  call symputx('uri3',uri);
  put (_all_)(=);
run;

/* no outref on purpose - the library is what used to break */
%mv_getjobresult(uri=&uri3
  ,result=WEBOUT_JSON
  ,outlib=myabortlib
)

%let abortrows=0;
%let abortmsg=;
%if %sysfunc(exist(myabortlib.sasjsAbort)) %then %do;
  data work.abortrows;
    set myabortlib.sasjsAbort;
  run;
  data _null_;
    set work.abortrows nobs=nobs;
    call symputx('abortrows',nobs,'l');
    call symputx('abortmsg',msg,'l');
  run;
%end;
%mp_assert(
  iftrue=(&abortrows=1),
  desc=Test3 - aborted child result parses despite the response envelope,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%index(%superq(abortmsg),deliberate abort)>0),
  desc=Test3b - the parsed result carries the abort message,
  outds=work.test_results
)
