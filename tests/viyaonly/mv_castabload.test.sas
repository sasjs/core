/**
  @file
  @brief Testing mv_castabload macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_castabload.sas

**/

options mprint;

/* -------------------------------------------------------------------- */
/* Setup: start a CAS session and stage a source file in the caslib     */
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

/* Save a sashdat source file then drop the in-memory copy so the first
    mv_castabload call has something to load                             */
proc casutil;
  load data=sashelp.baseball
    outcaslib="&testcaslib" casout="&tab1" replace;
  save casdata="&tab1" incaslib="&testcaslib"
    casout="&tab1..sashdat" outcaslib="&testcaslib" replace;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
quit;

libname mylib cas caslib="&testcaslib";


/* -------------------------------------------------------------------- */
%put TEST 1 - load a table that is not in memory;
/* -------------------------------------------------------------------- */

/* Confirm table is absent before the call */
%let _tabexists=0;
proc cas;
  table.tableExists result=r /
    caslib="&testcaslib" name="&tab1";
  if r.exists > 0 then call symputx('_tabexists','1');
quit;

%mp_assert(
  iftrue=(&_tabexists=0),
  desc=Check table is not in memory before mv_castabload
)

%mv_castabload(lib=mylib, table=&tab1, mdebug=1)

%let _tabexists=0;
proc cas;
  table.tableExists result=r /
    caslib="&testcaslib" name="&tab1";
  if r.exists > 0 then call symputx('_tabexists','1');
quit;

%mp_assert(
  iftrue=(&_tabexists=1),
  desc=Check table is in memory after mv_castabload
)


/* -------------------------------------------------------------------- */
%put TEST 2 - reload fetches a fresh copy and discards in-memory changes;
/* -------------------------------------------------------------------- */

/* Append a sentinel row to the in-memory table */
data work.extra;
  set mylib.&tab1;
  name='TESTROW';
  output;
  stop;
run;
proc casutil;
  load data=work.extra casout="&tab1"
    outcaslib="&testcaslib" append;
quit;

%let _modified=0;
proc sql noprint;
  select count(*) into :_modified
  from mylib.&tab1
  where name='TESTROW';
quit;

%mp_assert(
  iftrue=(&_modified=1),
  desc=Check sentinel row is present in memory before reload
)

/* Drop the table and reload - source file does not have the sentinel   */
proc casutil;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
quit;

%mp_assertscope(SNAPSHOT)

%mv_castabload(lib=mylib, table=&tab1, mdebug=1)

%mp_assertscope(COMPARE,
  desc=Check mv_castabload does not leak macro variables into GLOBAL scope
)

%let _after=0;
proc sql noprint;
  select count(*) into :_after
  from mylib.&tab1
  where name='TESTROW';
quit;

%mp_assert(
  iftrue=(&_after=0),
  desc=Check sentinel row is absent after reload from source
)


/* -------------------------------------------------------------------- */
/* Teardown                                                              */
/* -------------------------------------------------------------------- */
libname mylib clear;

proc casutil;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  deletesource casdata="&tab1..sashdat"
    incaslib="&testcaslib" quiet;
quit;

cas mysess terminate;

%let syscc=0;
