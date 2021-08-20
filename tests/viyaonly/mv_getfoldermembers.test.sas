/**
  @file
  @brief Testing mv_getfoldermembers macro
  @details Testing is performed by ensuring that the tests/macros folder
  contains more than 20 results (which also means the default was increased)

  <h4> SAS Macros </h4>
  @li mf_getapploc.sas
  @li mp_assertdsobs.sas
  @li mv_getfoldermembers.sas

**/
options mprint;

%mv_getfoldermembers(
  root=%mf_getapploc()/tests/macros,
  outds=work.results
)

%mp_assertdsobs(work.results,
  desc=%str(Ensuring over 20 results found in %mf_getapploc()/tests/macros),
  test=ATLEAST 21,
  outds=work.test_results
)