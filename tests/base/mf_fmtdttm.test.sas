/**
  @file
  @brief Testing mf_fmtdttm macro

  <h4> SAS Macros </h4>
  @li mf_fmtdttm.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%global test1;

%mp_assertscope(SNAPSHOT)
%let test1=%mf_fmtdttm();
%mp_assertscope(COMPARE,ignorelist=test1)

%mp_assert(
  iftrue=("&test1"="DATETIME19.3" or "&test1"="E8601DT26.6"),
  desc=Basic test,
  outds=work.test_results
)
