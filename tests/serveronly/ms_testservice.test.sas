/**
  @file
  @brief Testing ms_testservice.sas macro

  <h4> SAS Macros </h4>
  @li ms_createwebservice.sas
  @li ms_testservice.sas
  @li mp_assert.sas

**/

filename ft15f001 temp;
parmcards4;
  %put Initialising sendObj: ;
  %put _all_;
  %webout(FETCH)
  %webout(OPEN)
  %macro x();
  %if (%symexist(sasjs_tables) and %length(&sasjs_tables)>0)
  %then %do i=1 %to %sysfunc(countw(&sasjs_tables));
    %let table=%scan(&sasjs_tables,&i);
    %webout(OBJ,&table,missing=STRING)
  %end;
  %else %do i=1 %to &_webin_file_count;
    %webout(OBJ,&&_webin_name&i,missing=STRING)
  %end;
  %mend x; %x()
  %webout(CLOSE)
;;;;
%put creating web service: &mcTestAppLoc/services;
%ms_createwebservice(
  path=&mcTestAppLoc/services,
  name=sendObj,
  mdebug=&sasjs_mdebug
)
%put created web service: &mcTestAppLoc/services;

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

%ms_testservice(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata1 work.somedata2,
  debug=log,
  mdebug=1,
  outlib=testlib1,
  outref=test1
)

%let test1=FAIL;
data _null_;
  set testlib1.somedata1;
  if x=1 and y='  t"w"o' and z="Z" then call symputx('test1','PASS');
  putlog (_all_)(=);
run;

%let test2=FAIL;
data _null_;
  set testlib1.somedata2;
  if x=1 and y='  t"w"o' and z="Z" then call symputx('test2','PASS');
  putlog (_all_)(=);
run;


%mp_assert(
  iftrue=(&test1=PASS),
  desc=somedata1 created correctly,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test2=PASS),
  desc=somedata2 created correctly,
  outds=work.test_results
)
