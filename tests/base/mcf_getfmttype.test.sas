/**
  @file
  @brief Testing mcf_getfmttype.sas macro

  <h4> SAS Macros </h4>
  @li mcf_getfmttype.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%mcf_getfmttype()
%mp_assertscope(COMPARE,ignorelist=_SASJS_FUNCTIONS)

%mp_assert(
  iftrue=(%sysfunc(mcf_getfmttype(DATE9.))=DATE),
  desc=Check DATE format
)
%mp_assert(
  iftrue=(%sysfunc(mcf_getfmttype($6))=CHAR),
  desc=Check CHAR format
)
%mp_assert(
  iftrue=(%sysfunc(mcf_getfmttype(8.))=NUM),
  desc=Check NUM format
)
%mp_assert(
  iftrue=(%sysfunc(mcf_getfmttype(E8601DT))=DATETIME),
  desc=Check DATETIME format
)

/* these prove the lookups really come from mf_dttmfmts - neither name starts
  with DATE / TIME, so a prefix test would not find them */
%mp_assert(
  iftrue=(%sysfunc(mcf_getfmttype(MMDDYY9.))=DATE),
  desc=Check date format that is not DATE-prefixed
)
%mp_assert(
  iftrue=(%sysfunc(mcf_getfmttype(HHMM8.))=TIME),
  desc=Check time format that is not TIME-prefixed
)

/* test 2 - compile again test for warnings */
%mcf_getfmttype()

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check syscc=0 after re-initialisation
)
