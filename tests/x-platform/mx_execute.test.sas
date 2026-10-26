/**
  @file
  @brief Testing mx_execute.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mx_createwebservice.sas
  @li mx_execute.sas
  @li mp_assert.sas

**/

filename ft15f001 temp;
parmcards4;
  %put Initialising sendObj: ;
  %put _all_;
  %webout(FETCH)
  %webout(OPEN)
  %macro x();
  %if %symexist(sasjs_tables) %then %do i=1 %to %sysfunc(countw(&sasjs_tables));
    %let table=%scan(&sasjs_tables,&i);
    %webout(OBJ,&table,missing=STRING)
  %end;
  %else %do i=1 %to &_webin_file_count;
    %webout(OBJ,&&_webin_name&i,missing=STRING)
  %end;
  %mend x; %x()
  %webout(CLOSE)
;;;;
%mx_createwebservice(path=&mcTestAppLoc/services,name=sendObj)

%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors after service creation,
  outds=work.test_results
)

/**
  * Test 1 - send a dataset
  */
data work.somedata1 work.somedata2;
  x=1;
  y='  t"w"o';
  z=.z;
  y2='  two';
  label x='x factor';
  output;
run;

%mx_execute(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1 work.somedata2,
  debug=log,
  mdebug=1,
  outlib=testlib1,
  outref=test1
)
%let test1=FAIL;
data _null_;
  set testlib1.somedata1;
  if x=1 and y='  t"w"o' and z="Z" and y2='  two' then call symputx('test1','PASS');
  putlog (_all_)(=);
run;

%let test2=FAIL;
data _null_;
  set testlib1.somedata2;
  if x=1 and y='  t"w"o' and z="Z" and y2='  two' then call symputx('test2','PASS');
  putlog (_all_)(=);
run;


%mp_assert(
  iftrue=(&test1=PASS),
  desc=somedata1 created correctly,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test2=PASS),
  desc=somedata2 created correctly,
  outds=work.test_results
)

/**
  * Test 2 - the default call writes no log dataset
  */
proc datasets lib=work nolist nowarn;
  delete childlog;
quit;
%mx_execute(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1,
  debug=log,
  outlib=testlib3,
  outref=test3
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.childlog))=0),
  desc=Test 2 - no log dataset is written unless outlogds is asked for,
  outds=work.test_results
)

/**
  * Test 3 - the child log is kept when outlogds is supplied
  */
%macro mp_test_log();
  %if "%mf_getplatform()"=SAS9 %then %do;
    %put NOTE: proc stp returns no child log - outlogds case skipped on SAS 9;
    %return;
  %end;
  %mx_execute(&mcTestAppLoc/services/sendObj,
    inputdatasets=work.somedata1,
    debug=log,
    outlib=testlib4,
    outref=test4,
    outlogds=work.childlog
  )
  %let logcase=FAIL;
  data _null_;
    if not exist('work.childlog') then stop;
    set work.childlog;
    /* the service's first statement is a %put - it must be in the log */
    if index(line,'Initialising sendObj') then call symputx('logcase','PASS');
  run;
  %mp_assert(
    iftrue=("&logcase"="PASS"),
    desc=Test 3 - the child log is captured when outlogds is supplied,
    outds=work.test_results
  )
%mend mp_test_log;
%mp_test_log()
