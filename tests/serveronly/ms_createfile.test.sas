/**
  @file
  @brief Testing ms_createfile.sas macro

  <h4> SAS Macros </h4>
  @li ms_createfile.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/


filename stpcode temp;
data _null_;
  file stpcode;
  put '%put hello world;';
run;

options mprint;
%let fname=%mf_getuniquename();

%mp_assertscope(SNAPSHOT)
%ms_createfile(/sasjs/tests/&fname..sas
  ,inref=stpcode
  ,mdebug=1
)
%mp_assertscope(COMPARE)



