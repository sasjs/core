/**
  @file
  @brief Testing mv_getusers macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_getusers.sas

**/

/* the JSON libname engine publishes five globals per libref when it parses a
  REST response, and the libref numbers are fixed because each test runs in a
  fresh session.  They are listed so the comparison covers the macro's own
  variables. */
%mp_assertscope(SNAPSHOT)
%mv_getusers(outds=work.viyausers)
%mp_assertscope(COMPARE,
  desc=mv_getusers does not leak scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.viyausers))=1),
  desc=Check the users dataset was created
)
%mp_assert(
  iftrue=(%mf_nobs(work.viyausers)>0),
  desc=Check the users dataset has rows
)
%mp_assert(
  iftrue=(%mf_existvar(work.viyausers,name)>0),
  desc=Check the dataset carries a name column
)
