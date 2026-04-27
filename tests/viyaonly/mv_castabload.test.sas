/**
  @file
  @brief Testing mv_castabload macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_castabload.sas
  @li mv_createfile.sas

**/

options mprint;

/* ------------------------------------------------------------------------ */
/* Setup: start a CAS session and stage a source file in the Public caslib  */
/* ------------------------------------------------------------------------ */
cas mysess;
caslib _all_ assign;

%let testcaslib = Public;   /* change this if Public isn't available */
proc cas;
  table.caslibInfo result=r / ;
  found = 0;
  do row over r.CASLibInfo;
    if upcase(row.Name) = upcase("&testcaslib") then found = 1;
  end;
  if found = 0 then do;
    print "ERROR: caslib &testcaslib not available";
    exit;
  end;
quit;
%put NOTE: Using testcaslib=&testcaslib;

%let tab1=T%mf_uid();
%let tab2=T%mf_uid();
%let tab3=T%mf_uid();

/* Create a SASHDAT source file in the Public caslib from SASHELP.BASEBALL
    so that subsequent LOAD operations have something real to pick up.      */
proc casutil;
  load data=sashelp.baseball outcaslib="&testcaslib" casout="&tab1" replace;
  save casdata="&tab1" incaslib="&testcaslib"
    casout="&tab1..sashdat" outcaslib="&testcaslib" replace;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
quit;

/* And a second hdat, with a name different from the table name, so that we
  can exercise the explicit srcfile= path. */
proc casutil;
  load data=sashelp.cars outcaslib="&testcaslib" casout="&tab2" replace;
  save casdata="&tab2" incaslib="&testcaslib"
    casout="src_&tab2..sashdat" outcaslib="&testcaslib" replace;
  droptable casdata="&tab2" incaslib="&testcaslib" quiet;
quit;


/* ------------------------------------------------------------------------ */
%put TEST 1 - missing required parameters returns without setting RC to 0/1;
/* ------------------------------------------------------------------------ */
%let MV_CASTABLOAD_RC=;
%mv_castabload(caslib=,table=,srcfile=)

%mp_assert(
  iftrue=(&MV_CASTABLOAD_RC=3),
  desc=Check RC=3 (initial/failure value) when required params are missing
)


/* ------------------------------------------------------------------------ */
%put TEST 2 - load a table that does not yet exist (default srcfile=table.sashdat);
/* ------------------------------------------------------------------------ */
%mv_castabload(caslib=&testcaslib,table=&tab1,mdebug=1)

%mp_assert(
  iftrue=(&MV_CASTABLOAD_RC=1),
  desc=Check RC=1 when table is loaded and promoted for the first time
)


/* ------------------------------------------------------------------------ */
%put TEST 3 - calling again for the same table should be a no-op (RC=0);
/*              also verify no scope leakage of macro variables              */
/* ------------------------------------------------------------------------ */
%mp_assertscope(SNAPSHOT)

%mv_castabload(caslib=&testcaslib,table=&tab1,mdebug=1)

%mp_assertscope(COMPARE,
  desc=Check mv_castabload does not leak macro variables into GLOBAL scope,
  ignorelist=MV_CASTABLOAD_RC
)

%mp_assert(
  iftrue=(&MV_CASTABLOAD_RC=0),
  desc=Check RC=0 when table is already in-memory (skip load)
)


/* ------------------------------------------------------------------------ */
%put TEST 4 - explicit srcfile= where file name differs from table name;
/* ------------------------------------------------------------------------ */
%mv_castabload(
  caslib=&testcaslib,
  table=&tab2,
  srcfile=src_&tab2..sashdat,
  mdebug=1
)

%mp_assert(
  iftrue=(&MV_CASTABLOAD_RC=1),
  desc=Check RC=1 when loading with explicit srcfile= parameter
)


/* ------------------------------------------------------------------------ */
%put TEST 5 - load failure when srcfile does not exist in the caslib;
/* ------------------------------------------------------------------------ */
%mv_castabload(
  caslib=&testcaslib,
  table=&tab3,
  srcfile=doesnotexist_%mf_uid..sashdat,
  mdebug=1
)

%mp_assert(
  iftrue=(&MV_CASTABLOAD_RC=3),
  desc=Check RC=3 when source file cannot be found / load fails
)

/* reset so that a downstream failure RC does not break testterm */
%let syscc=0;


/* ------------------------------------------------------------------------ */
/* Teardown: drop promoted tables and remove source files                   */
/* ------------------------------------------------------------------------ */
proc casutil;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
  droptable casdata="&tab2" incaslib="&testcaslib" quiet;
  deletesource casdata="&tab1..sashdat" incaslib="&testcaslib" quiet;
  deletesource casdata="src_&tab2..sashdat" incaslib="&testcaslib" quiet;
quit;

cas mysess terminate;

%let syscc=0;
