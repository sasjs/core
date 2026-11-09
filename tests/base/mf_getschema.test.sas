/**
  @file
  @brief Testing mf_getschema macro

  <h4> SAS Macros </h4>
  @li mf_getschema.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

  @details A positive case needs a library whose engine publishes a schema
  through SYSNAME (a database library).  The base engine does not, so the
  assertions here cover the two branches that can be reached without one: a
  base library and a libref that is not assigned, both of which must return
  nothing without raising an error.

**/

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getschema(WORK);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getschema does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getschema(WORK))=0),
  desc=Checking that a base engine library returns no schema,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getschema(nosuchlib))=0),
  desc=Checking that a library that is not assigned returns nothing,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getschema(sashelp.class))=0),
  desc=Checking that a two level libds reference is accepted,
  outds=work.test_results
)
