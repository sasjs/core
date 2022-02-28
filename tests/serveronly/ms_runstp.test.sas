/**
  @file
  @brief Testing ms_runstp.sas macro

  <h4> SAS Macros </h4>
  @li ms_runstp.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%ms_runstp(/Public/app/frs/allan/services/common/appinit
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

data work.httpheaders;
  set webeen.httpheaders;
  call symputx('test1',content_type);
run;

data work.log;
  set webeen.log;
  put (_all_)(=);
  if _n_>10 then stop;
run;

%mp_assert(
  iftrue=("&test1"="application/json"),
  desc=Checking line was created,
  outds=work.test_results
)


