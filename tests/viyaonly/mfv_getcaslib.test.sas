/**
  @file
  @brief Testing mfv_getcaslib macro function

  <h4> SAS Macros </h4>
  @li mfv_getcaslib.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

options mprint;

/* ------------------------------------------------------------------------ */
/* Setup: start a CAS session and assign caslibs                            */
/* ------------------------------------------------------------------------ */
cas mysess;
caslib _all_ assign;

%let testcaslib=Public;

libname castest cas caslib=&testcaslib;

/* ------------------------------------------------------------------------ */
%put TEST 1 - returns the caslib name for a valid CAS libref;
/* ------------------------------------------------------------------------ */
%mp_assert(
  iftrue=(%mfv_getcaslib(castest)=%upcase(&testcaslib)),
  desc=Check correct caslib name returned for a valid CAS libref
)


/* ------------------------------------------------------------------------ */
%put TEST 2 - returns empty for a non-CAS libref (WORK);
/* ------------------------------------------------------------------------ */
%mp_assert(
  iftrue=(%mfv_getcaslib(WORK)=),
  desc=Check empty string returned for a non-CAS libref
)


/* ------------------------------------------------------------------------ */
%put TEST 3 - returns empty for a libref that does not exist;
/* ------------------------------------------------------------------------ */
%mp_assert(
  iftrue=(%mfv_getcaslib(DOESNOTEXIST)=),
  desc=Check empty string returned for a non-existent libref
)


/* ------------------------------------------------------------------------ */
%put TEST 5 - no scope leakage into global macro variables;
/* ------------------------------------------------------------------------ */
%mp_assertscope(SNAPSHOT)

%let _rc=%mfv_getcaslib(castest);

%mp_assertscope(COMPARE,
  desc=Check mfv_getcaslib does not leak macro variables into GLOBAL scope,
  ignorelist=_RC
)


/* ------------------------------------------------------------------------ */
/* Teardown                                                                  */
/* ------------------------------------------------------------------------ */
cas mysess terminate;


