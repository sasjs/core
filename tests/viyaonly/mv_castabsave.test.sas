/**
  @file
  @brief Testing mv_castabsave macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_castabsave.sas

**/

options mprint;

/* -------------------------------------------------------------------- */
/* Setup: start a CAS session and load a table that has a tracked       */
/*        source file so mv_castabsave can discover it via the REST API */
/* -------------------------------------------------------------------- */
cas mysess;
caslib _all_ assign;

%let testcaslib=Public;

proc cas;
  table.caslibInfo result=r / ;
  found=0;
  do row over r.CASLibInfo;
    if upcase(row.Name)=upcase("&testcaslib") then found=1;
  end;
  if found=0 then do;
    print "ERROR: caslib &testcaslib not available";
    exit;
  end;
quit;
%put NOTE: Using testcaslib=&testcaslib;

%let tab1=T%mf_uid();

/* Load sashelp.class into CAS, save as sashdat, reload from that file
    so the table has a tracked source path (needed for REST discovery) */
proc casutil;
  load data=sashelp.class
    outcaslib="&testcaslib" casout="&tab1" replace;
  save casdata="&tab1" incaslib="&testcaslib"
    casout="&tab1..sashdat" outcaslib="&testcaslib" replace;
  /* Drop any existing global-scope version before promoting */
  /* runs twice (with quiet) as first would drop local scope if exists */
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;

  load casdata="&tab1..sashdat" incaslib="&testcaslib"
    casout="&tab1" outcaslib="&testcaslib" promote;
quit;

libname mylib cas caslib="&testcaslib";


/* -------------------------------------------------------------------- */
%put TEST 1 - save in-memory table back to disk + no scope leakage;
/* -------------------------------------------------------------------- */

/* Source file is removed so that the reload proves mv_castabsave
    created the file from scratch, not that a prior version existed   */
proc casutil;
  deletesource casdata="&tab1..sashdat"
    incaslib="&testcaslib" quiet;
quit;

/* Insert a sentinel row - it must survive the full save/drop/reload   */
data work.appendme;
  set mylib.&tab1;
  name='TESTROW';
  output;
  stop;
proc casutil;
  load data=work.appendme casout="&tab1" outcaslib="&testcaslib" append;
quit;

%mp_assertscope(SNAPSHOT)

%mv_castabsave(lib=mylib, table=&tab1, mdebug=1)

%mp_assertscope(COMPARE,
  desc=Check mv_castabsave does not leak macro variables into GLOBAL scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
)

proc casutil;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  load casdata="&tab1..sashdat" incaslib="&testcaslib"
    casout="&tab1" outcaslib="&testcaslib" promote;
quit;

%let _rowcount=0;
proc sql noprint;
  select count(*) into :_rowcount
  from mylib.&tab1
  where name='TESTROW';
quit;

%mp_assert(
  iftrue=(&_rowcount=1),
  desc=Check inserted row survives mv_castabsave round-trip to disk
)


/* -------------------------------------------------------------------- */
%put TEST 2 - save overwrites an existing source file;
/* -------------------------------------------------------------------- */

/* Source file already exists from the TEST 1 save - append a new row  */
data work.appendme;
  set mylib.&tab1;
  name='TESTROW2';
  output;
  stop;
proc casutil;
  load data=work.appendme casout="&tab1"
    outcaslib="&testcaslib" append;
quit;

%mv_castabsave(lib=mylib, table=&tab1, mdebug=1)

proc casutil;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  load casdata="&tab1..sashdat" incaslib="&testcaslib"
    casout="&tab1" outcaslib="&testcaslib" promote;
quit;

%let _rowcount=0;
proc sql noprint;
  select count(*) into :_rowcount
  from mylib.&tab1
  where name='TESTROW2';
quit;

%mp_assert(
  iftrue=(&_rowcount=1),
  desc=Check inserted row survives save over an existing source file
)


/* -------------------------------------------------------------------- */
/* Teardown                                                              */
/* -------------------------------------------------------------------- */
libname mylib clear;

proc casutil;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  deletesource casdata="&tab1..sashdat"
    incaslib="&testcaslib" quiet;
quit;

cas mysess terminate;

%let syscc=0;
