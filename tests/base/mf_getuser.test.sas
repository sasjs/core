/**
  @file
  @brief Testing mf_getuser macro

  <h4> SAS Macros </h4>
  @li mf_getuser.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getuser();
%mp_assertscope(COMPARE,
  desc=Checking that mf_getuser does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getuser())>0),
  desc=Checking that a user is always returned,
  outds=work.test_results
)

%if %symexist(_sasjs_username) %then %do;
  %mp_assert(
    iftrue=(%mf_getuser()=&_sasjs_username),
    desc=Checking that the SASjs end user is preferred over the session account,
    outds=work.test_results
  )
  %mp_assert(
    iftrue=(%mf_getuser() ne &sysuserid),
    desc=Checking that the session account is not reported as the user,
    outds=work.test_results
  )
%end;
%else %do;
  %mp_assert(
    iftrue=(%mf_getuser()=&sysuserid),
    desc=Checking that the session account is reported with no end user present,
    outds=work.test_results
  )
%end;
