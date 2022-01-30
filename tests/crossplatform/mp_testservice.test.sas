/**
  @file
  @brief Testing mp_testservice.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  runnin in Studio

  <h4> SAS Macros </h4>
  @li mp_createwebservice.sas
  @li mp_testservice.sas
  @li mp_assert.sas

**/


filename ft15f001 temp;
parmcards4;
  %webout(FETCH)
  %webout(OPEN)
  %macro x();
    %do i=1 %to &_webin_file_count;
      %webout(OBJ,&&_webin_name&i,missing=STRING)
    %end;
  %mend x; %x()
  %webout(CLOSE)
;;;;
%mp_createwebservice(path=&mcTestAppLoc/services,name=sendObj)

%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors after service creation,
  outds=work.test_results
)

/**
  * Test 1 - send a dataset
  */
data work.somedata1 work.somedata2;
  x=1;
  y='  t"w"o';
  z=.z;
  label x='x factor';
  output;
run;

%mp_testservice(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1 work.somedata2,
  debug=log,
  mdebug=1,
  outlib=testlib1,
  outref=test1
)

%global test1a test1b test1c test1d;
data _null_;
  infile test1;
  input;
  if _n_=3 then do;
    if _infile_=', "somedata1":' then call symputx('test1a','PASS');
    else putlog _n_= _infile_=;
  end;
  else if _n_=5 then do;
    if _infile_='{"X":1 ,"Y":"  t\"w\"o" ,"Z":"Z" }' then
      call symputx('test1b','PASS');
    else putlog _n_= _infile_=;
  end;
  else if _n_=6 then do;
    if _infile_='], "somedata2":' then call symputx('test1c','PASS');
    else putlog _n_= _infile_=;
  end;
  else if _n_=8 then do;
    if _infile_='{"X":1 ,"Y":"  t\"w\"o" ,"Z":"Z" }' then
      call symputx('test1d','PASS');
    else putlog _n_= _infile_=;
  end;
run;

%mp_assert(
  iftrue=(&test1a=PASS),
  desc=Test 1 table 1 name,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test1b=PASS),
  desc=Test 1 table 1 values,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test1c=PASS),
  desc=Test 1 table 2 name,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test1d=PASS),
  desc=Test 1 table 2 values,
  outds=work.test_results
)