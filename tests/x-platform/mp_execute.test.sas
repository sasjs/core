/**
  @file
  @brief Testing mp_execute.sas macro
  @details mp_execute is a thin wrapper around mx_testservice - this test
  verifies the wrapper delegates correctly by creating and executing a real
  service.

  <h4> SAS Macros </h4>
  @li mx_createwebservice.sas
  @li mp_execute.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

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
%mx_createwebservice(path=&mcTestAppLoc/services,name=sendObj)

%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors after service creation,
  outds=work.test_results
)

/**
  * Test 1 - execute the service via mp_execute
  */
data work.somedata;
  x=1;
  y='  t"w"o';
  z=.z;
  y2='  two';
  label x='x factor';
  output;
run;

%mp_assertscope(SNAPSHOT)
%mp_execute(&mcTestAppLoc/services/sendObj,
  inputdatasets=work.somedata,
  debug=log,
  mdebug=1,
  outlib=testlib,
  outref=test1
)
/* ignore macro vars created by the JSON libname engine */
%mp_assertscope(COMPARE
  ,ignorelist=TESTLIB_JADP1LEN TESTLIB_JADP2LEN TESTLIB_JADPNUM TESTLIB_JADVLEN
)

%let test1=FAIL;
data _null_;
  set testlib.somedata;
  if x=1 and y='  t"w"o' and z="Z" and y2='  two'
  then call symputx('test1','PASS');
  putlog (_all_)(=);
run;

%mp_assert(
  iftrue=(&test1=PASS),
  desc=mp_execute delegates correctly and returns input dataset,
  outds=work.test_results
)
