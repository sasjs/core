/**
  @file
  @brief Testing mf_getengine macro

  <h4> SAS Macros </h4>
  @li mf_getengine.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getengine(WORK);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getengine does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getengine(WORK)=V9),
  desc=Checking that the WORK library reports the V9 engine,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getengine(SASHELP)=V9),
  desc=Checking that the SASHELP library reports the V9 engine,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getengine(sashelp.class)=V9),
  desc=Checking that a two level libds reference is accepted,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getengine(nosuchlib))=0),
  desc=Checking that a library that is not assigned returns nothing,
  outds=work.test_results
)
