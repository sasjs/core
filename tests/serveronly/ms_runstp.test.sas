/**
  @file
  @brief Testing ms_runstp.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_createfile.sas
  @li ms_runstp.sas

**/

/* first, create an STP to run */
filename stpcode temp;
data _null_;
  file stpcode;
  put '%put hello world;';
run;

options mprint;
%let fname=%mf_getuniquename();

%ms_createfile(/sasjs/tests/&fname..sas
  ,inref=stpcode
  ,mdebug=1
)

%mp_assertscope(SNAPSHOT)
%ms_runstp(/sasjs/tests/&fname
  ,debug=131
  ,outref=weboot
)
%mp_assertscope(COMPARE)

libname webeen json (weboot);

data _null_;
  infile weboot;
  input;
  putlog _infile_;
run;

%let test1=0;
data work.log;
  set webeen.log;
  put (_all_)(=);
  if _n_>10 then call symputx('test1',1);
run;

%mp_assert(
  iftrue=("&test1"="1"),
  desc=Checking log was returned,
  outds=work.test_results
)


