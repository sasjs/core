/**
  @file
  @brief Testing mfv_existsashdat macro function

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_existsashdat.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

options mprint;

/* ------------------------------------------------------------------------ */
/* Setup: start a CAS session and stage a sashdat file in the Public caslib */
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

proc casutil;
  load data=sashelp.baseball outcaslib="&testcaslib" casout="&tab1" replace;
  save casdata="&tab1" incaslib="&testcaslib"
    casout="&tab1..sashdat" outcaslib="&testcaslib" replace;
  droptable casdata="&tab1" incaslib="&testcaslib" quiet;
quit;


/* ------------------------------------------------------------------------ */
%put TEST 1 - returns 1 when the sashdat file exists in the caslib;
/* ------------------------------------------------------------------------ */
%mp_assert(
  iftrue=(%mfv_existsashdat(&testcaslib..&tab1)=1),
  desc=Test 1 - Check returns 1 for a sashdat that exists
)

/* ------------------------------------------------------------------------ */
%put TEST 2 - returns 0 when the file does not exist in the caslib;
/* ------------------------------------------------------------------------ */
%mp_assertscope(SNAPSHOT)
%mp_assert(
  iftrue=(%mfv_existsashdat(&testcaslib..DOESNOTEXIST_%mf_uid())=0),
  desc=Check returns 0 for a sashdat that does not exist
)
%mp_assertscope(COMPARE,
  desc=Check mfv_existsashdat does not leak macro variables into GLOBAL scope
)

/* ------------------------------------------------------------------------ */
/* Teardown                                                                 */
/* ------------------------------------------------------------------------ */
proc casutil;
  deletesource casdata="&tab1..sashdat" incaslib="&testcaslib" quiet;
quit;

cas mysess terminate;

%let syscc=0;
