/**
  @file
  @brief Testing ms_deletefile.sas macro

  <h4> SAS Macros </h4>
  @li ms_createfile.sas
  @li ms_deletefile.sas
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

%ms_getfile(/sasjs/tests/&fname..sas,outref=testref)

%let test1=0;
data _null_;
  infile testref;
  input;
  call symputx('test1',_infile_);
run;

%mp_assert(
  iftrue=("&test1"="data &fname;run;"),
  desc=Make sure the file was created,
  outds=work.test_results
)

%mp_assertscope(SNAPSHOT)
%ms_deletefile(/sasjs/tests/&fname..sas,mdebug=1)
%mp_assertscope(COMPARE)

%ms_getfile(/sasjs/tests/&fname..sas,outref=testref2)

%let test2=0;
data _null_;
  infile testref2;
  input;
  call symputx('test2',_infile_);
run;

%mp_assert(
  iftrue=("&test2"="File doesn't exist."),
  desc=Make sure the file was deleted,
  outds=work.test_results
)


