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
  %put Initialising sendObj: ;
  %put _all_;
  %webout(FETCH)
  %webout(OPEN)
  %macro x();
  %if %symexist(sasjs_tables) %then %do i=1 %to %sysfunc(countw(&sasjs_tables));
    %let table=%scan(&sasjs_tables,&i);
    %webout(OBJ,&table,missing=STRING)
  %end;
  %else %do i=1 %to &_webin_file_count;
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
  putlog _n_ _infile_;
  if _infile_=', "somedata1":' then call symputx('test1a','PASS');
  if _infile_='{"X":1 ,"Y":"  t\"w\"o" ,"Z":"Z" }' then
    call symputx('test1b','PASS');
  if _infile_='], "somedata2":' then call symputx('test1c','PASS');
  if _infile_='{"X":1 ,"Y":"  t\"w\"o" ,"Z":"Z" }' then
      call symputx('test1d','PASS');
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