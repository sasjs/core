/**
  @file
  @brief Testing mx_createwebservice macro

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mx_createwebservice.sas

**/

%let path=&mcTestAppLoc/mx_createwebservice;
%let name=myservice;
%let fref=%mf_getuniquefileref();

data _null_;
  file &fref;
  put '%put hello world;';
run;

%mp_assertscope(SNAPSHOT)
%mx_createwebservice(path=&path, name=&name, code=&fref)
%mp_assertscope(COMPARE,
  desc=mx_createwebservice does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check the service was created without error
)
