/**
  @file
  @brief Testing mcf_getfmttype.sas macro

  <h4> SAS Macros </h4>
  @li mcf_getfmttype.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%mcf_getfmttype(wrap=YES, insert_cmplib=YES)
%mp_assertscope(COMPARE,ignorelist=SASJS_FUNCTIONS)

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

/* test 2 - compile again test for warnings */
%mcf_getfmttype(wrap=YES, insert_cmplib=YES)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check syscc=0 after re-initialisation
)