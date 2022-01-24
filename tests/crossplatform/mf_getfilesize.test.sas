/**
  @file
  @brief Testing mf_getfilesize macro

  <h4> SAS Macros </h4>
  @li mf_getfilesize.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data test;
  x=1;
run;

%mp_assertscope(SNAPSHOT)
%put %mf_getfilesize(libds=work.test)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking syscc,
  outds=work.test_results
)

%put %mf_getfilesize(libds=test)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking syscc with one level name,
  outds=work.test_results
)