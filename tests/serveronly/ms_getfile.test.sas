/**
  @file
  @brief Testing ms_getfile.sas macro

  <h4> SAS Macros </h4>
  @li ms_createfile.sas
  @li ms_getfile.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/


/* first make a remote file */
filename stpcode temp;
%let fname=%mf_getuniquename();
data _null_;
  file stpcode;
  put "data &fname;run;";
run;
%ms_createfile(/sasjs/tests/&fname..sas
  ,inref=stpcode
  ,mdebug=1
)

%mp_assertscope(SNAPSHOT)
%ms_getfile(/sasjs/tests/&fname..sas,outref=testref)
%mp_assertscope(COMPARE)

%let test1=0;
data _null_;
  infile testref;
  input;
  call symputx('test1',_infile_);
run;

%mp_assert(
  iftrue=("&test1"="data &fname;run;"),
  desc=Checking file was created with the same content,
  outds=work.test_results
)




