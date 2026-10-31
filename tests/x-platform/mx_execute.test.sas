/**
  @file
  @brief Testing mx_execute.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_assert.sas
  @li mx_createwebservice.sas
  @li mx_execute.sas

  @sasjslint {"maxLineLength": 84, "noUnusedMacros": false}
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
%mx_execute(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1,
  outlib=testlib4,
  outref=test4,
  outlogds=work.childlog
)

/* The log arrives as text after the separator.  SAS 9 has no log to return, so
  * the expectation is met there without one - expressed here rather than with a
  * platform %if, so the test stays one program on every platform. */
%let logcase=FAIL;
%let logsize=FAIL;
data _null_;
  length line $32767;
  retain found 0;
  n=0;
  if exist('work.childlog') then do;
    /* count from the descriptor: a do-until loop runs once on an empty
      * dataset, which would report the SAS 9 empty log as one line */
    dsid=open('work.childlog');
    n=attrn(dsid,'NOBS');
    rc=close(dsid);
    if n>0 then do until(eof);
      set work.childlog(keep=line) end=eof;
      /* the service's first statement is a %put - it must be in the log */
      if index(line,'Initialising sendObj') then found=1;
    end;
  end;
  call symputx('loglines',n);
  if "&mcTestPlatform"="SASMETA" then do;
    /* documented: SAS 9 returns no child log, so the dataset exists with no
      * rows - anything else means something was captured from nowhere */
    call symputx('logcase',ifc(n=0,'PASS','FAIL'));
    call symputx('logsize','PASS');
  end;
  else do;
    call symputx('logcase',ifc(found,'PASS','FAIL'));
    /* a fragment that happens to contain the first line would still pass the
      * marker test, so pin the volume too */
    call symputx('logsize',ifc(n>50,'PASS','FAIL'));
  end;
run;

%mp_assert(
  iftrue=("&logcase"="PASS"),
  desc=Test 3 - the child log is captured when outlogds is supplied,
  outds=work.test_results
)

%mp_assert(
  iftrue=("&logsize"="PASS"),
  desc=Test 3 - the captured log is the whole log not a fragment (&loglines lines),
  outds=work.test_results
)

/**
  * Test 4 - the outcome of a clean run is reported, not left in WORK
  */
%mx_execute(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1,
  outlib=testlib5,
  outref=test5,
  outstatus=work.status5
)

%let state5=NONE;
data _null_;
  if not exist('work.status5') then stop;
  set work.status5;
  call symputx('state5',state);
run;

%mp_assert(
  iftrue=("&state5"="completed"),
  desc=Test 4 - a clean run reports state=completed,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.results))=0),
  desc=Test 4 - no fixed-name table is left in the caller WORK,
  outds=work.test_results
)

/**
  * Test 5 - an aborted child is reported as canceled, with its message
  */
filename ft15f002 temp;
data _null_;
  file ft15f002;
  /* the abort comes first, as it does in a real service: mp_abort opens the
    * response itself, so nothing needs to precede it */
  put '%mp_abort(iftrue=(1=1),msg=Deliberate abort);';
run;
/* code= must be named: mx_createwebservice defaults to ft15f001, which still
  * holds the sendObj source, so the service would silently be a copy of it */
%mx_createwebservice(path=&mcTestAppLoc/services,name=abortObj,code=ft15f002)

%mx_execute(&mcTestAppLoc/services/abortObj,
  outref=test6,
  outstatus=work.status6
)

/* SAS 9 reports unknown - proc stp returns no job status - so that is the
  * expected value there, and there is no child message to look for. */
%let state6=NONE;
%let msg6=;
data _null_;
  length expect $20;
  if "&mcTestPlatform"="SASMETA" then expect='unknown';
  else expect='canceled';
  call symputx('expect6',expect);
  if exist('work.status6') then do;
    set work.status6;
    call symputx('state6',state);
    call symputx('msg6',errmsg);
  end;
run;

%mp_assert(
  iftrue=("&state6"="&expect6"),
  desc=Test 5 - an aborted child reports its outcome,
  outds=work.test_results
)

%let msgcase=FAIL;
data _null_;
  if "&mcTestPlatform"="SASMETA" then call symputx('msgcase','PASS');
  else if %index("&msg6","Deliberate abort")>0 then call symputx('msgcase','PASS');
run;

%mp_assert(
  iftrue=("&msgcase"="PASS"),
  desc=Test 5 - the abort message from the child is reported,
  outds=work.test_results
)

/**
  * Test 5b - the abort message is the whole message, not what fits on one line
  *
  * The capture that fills errmsg stops at an escaped quote, and the variable
  * held 256 bytes, so a message carrying either arrived truncated.  Both are
  * reported in full now.
  */
filename ft15f003 temp;
data _null_;
  file ft15f003;
  put '%mp_abort(iftrue=(1=1),msg=%nrstr(alpha "quoted" beta));';
run;

%mx_createwebservice(path=&mcTestAppLoc/services,name=abortQuote,code=ft15f003)

%mx_execute(&mcTestAppLoc/services/abortQuote,
  outref=testsq,
  outstatus=work.statusq
)

filename ft15f004 temp;
data _null_;
  file ft15f004;
  length big $400;
  big=repeat('a message that runs on ',20);
  put '%mp_abort(iftrue=(1=1),msg=' big +(-1) ');';
run;

%mx_createwebservice(path=&mcTestAppLoc/services,name=abortLong,code=ft15f004)

%mx_execute(&mcTestAppLoc/services/abortLong,
  outref=testlg,
  outstatus=work.statuslg
)

/* a comma and a percent sign: the two characters a message picks up from real
  code, and the ones most likely to be lost on the way from the child's message
  into a macro variable or a function argument */
filename ft15f005 temp;
data _null_;
  file ft15f005;
  put '%mp_abort(iftrue=(1=1),msg=%nrstr(alpha, beta 100% gamma));';
run;

%mx_createwebservice(path=&mcTestAppLoc/services,name=abortComma,code=ft15f005)

%mx_execute(&mcTestAppLoc/services/abortComma,
  outref=testcm,
  outstatus=work.statuscm
)

%let quote6=NONE;
%let long6=0;
%let comma6=NONE;
data _null_;
  if exist('work.statusq') then do;
    set work.statusq;
    if index(errmsg,'quoted" beta')>0 then call symputx('quote6','PASS');
    else call symputx('quote6','FAIL');
  end;
  if exist('work.statuslg') then do;
    set work.statuslg;
    call symputx('long6',length(errmsg));
  end;
  if exist('work.statuscm') then do;
    set work.statuscm;
    if index(errmsg,'alpha, beta 100% gamma')>0 then call symputx('comma6','PASS');
    else call symputx('comma6','FAIL');
  end;
run;

%mp_assert(
  iftrue=("&quote6"="PASS" or "&mcTestPlatform"="SASMETA"),
  desc=Test 5b - a quote in the child message survives,
  outds=work.test_results
)

%mp_assert(
  iftrue=("&comma6"="PASS" or "&mcTestPlatform"="SASMETA"),
  desc=Test 5b - a comma and a percent sign in the child message survive,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&long6>256 or "&mcTestPlatform"="SASMETA"),
  desc=Test 5b - a long child message is reported in full (&long6 bytes),
  outds=work.test_results
)

/**
  * Test 6 - the plain default call, with no outref, outlib or outstatus
  */
/* clear what Test 3 left, so the assertion below is about this call only */
proc datasets lib=work nolist nowarn;
  delete childlog;
quit;
%mx_execute(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 6 - the default call runs without error,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.childlog))=0 and %sysfunc(exist(work.results))=0),
  desc=Test 6 - the default call leaves no log or flow table behind,
  outds=work.test_results
)
