/**
  @file
  @brief Testing ms_createwebservice.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_assertscope.sas
  @li ms_createwebservice.sas

**/

%let path=&mcTestAppLoc/ms_createwebservice;
%let name=myservice;
%let fref=%mf_getuniquefileref();

data _null_;
  file &fref lrecl=3000;
  put '%put hello world;';
run;

%mp_assertscope(SNAPSHOT)
%ms_createwebservice(path=&path,name=&name,code=&fref,mdebug=&sasjs_mdebug)
%mp_assertscope(COMPARE)





