/**
  @file
  @brief Testing mx_execute.sas on SASjs Server

  @details The outlogds parameter exists so a caller can keep the child's SAS
  log: the server appends it to the response and ms_testservice discards it
  unless asked.  These cases cover the pass-through and confirm the default
  path is untouched.

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li ms_createfile.sas
  @li ms_deletefile.sas
  @li mx_execute.sas

**/

%let pgmname=%mf_getuniquename();
%let driveloc=/sasjs/tests/&pgmname..sas;

filename stpcode temp;
data _null_;
  file stpcode termstr=crlf;
  put '%put MX_EXECUTE_OUTLOGDS_MARKER;';
  put 'data _null_;';
  put '  file _webout;';
  put '  put "child webout";';
  put 'run;';
run;

%ms_createfile(&driveloc
  ,inref=stpcode
  ,mdebug=&sasjs_mdebug
)

/**
  * Test 1 - the child's webout is returned, and its log is captured
  */
%let weboutref=%mf_getuniquefileref();
%mx_execute(/sasjs/tests/&pgmname
  ,outref=&weboutref
  ,outlogds=work.childlog
)

%let weboutfound=0;
data _null_;
  infile &weboutref end=last lrecl=32767;
  input;
  if index(_infile_,'child webout') then call symputx('weboutfound',1);
run;

%mp_assert(
  iftrue=(&weboutfound=1),
  desc=Test 1 - the child webout is returned,
  outds=work.test_results
)

%let logfound=0;
data _null_;
  if not exist('work.childlog') then stop;
  set work.childlog;
  if index(line,'MX_EXECUTE_OUTLOGDS_MARKER') then call symputx('logfound',1);
run;

%mp_assert(
  iftrue=(&logfound=1),
  desc=Test 1 - the child log is captured when outlogds is supplied,
  outds=work.test_results
)

/**
  * Test 2 - without outlogds the call still returns the webout, and no log
  * dataset appears (the default is unchanged)
  */
%let weboutref2=%mf_getuniquefileref();
proc datasets lib=work nolist nowarn;
  delete childlog;
quit;
%mx_execute(/sasjs/tests/&pgmname
  ,outref=&weboutref2
)

%let weboutfound2=0;
data _null_;
  infile &weboutref2 end=last lrecl=32767;
  input;
  if index(_infile_,'child webout') then call symputx('weboutfound2',1);
run;

%mp_assert(
  iftrue=(&weboutfound2=1),
  desc=Test 2 - the default call still returns the child webout,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.childlog))=0),
  desc=Test 2 - no log dataset is written unless outlogds is asked for,
  outds=work.test_results
)

/* clean up the stored program */
%ms_deletefile(&driveloc
  ,mdebug=&sasjs_mdebug
)
filename stpcode clear;
filename &weboutref clear;
filename &weboutref2 clear;
