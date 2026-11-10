/**
  @file
  @brief Testing mv_getgroups macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_getgroups.sas

**/

/* the JSON libname engine publishes five globals per libref when it parses a
  REST response, and the libref numbers are fixed because each test runs in a
  fresh session.  They are listed so the comparison covers the macro's own
  variables. */
%mp_assertscope(SNAPSHOT)
%mv_getgroups(outds=work.viyagroups)
%mp_assertscope(COMPARE,
  desc=mv_getgroups does not leak scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.viyagroups))=1),
  desc=Check the groups dataset was created
)
%mp_assert(
  iftrue=(%mf_nobs(work.viyagroups)>0),
  desc=Check the groups dataset has rows
)
%mp_assert(
  iftrue=(%mf_existvar(work.viyagroups,name)>0),
  desc=Check the dataset carries a name column
)
