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
  put '%put _all_;';
  put 'data _null_; file _webout; put "runstptest";run;';
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

%let test1=0;
%let test2=0;
data _null_;
  infile weboot;
  input;
  if _n_=1 then call symputx('test1',_infile_);
  if _n_=3 then do;
    call symputx('test2',substr(_infile_,1,30));
    putlog "SASJS_LOGS_SEPARATOR_xxx"; /* this marker affects the CLI parser */
  end;
  else putlog _infile_;
run;



%mp_assert(
  iftrue=("&test1"="runstptest"),
  desc=Checking webout was created,
  outds=work.test_results
)

%mp_assert(
  iftrue=("&test2"="SASJS_LOGS_SEPARATOR_163ee17b6"),
  desc=Checking debug was enabled,
  outds=work.test_results
)
