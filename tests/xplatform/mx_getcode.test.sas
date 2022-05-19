/**
  @file
  @brief Testing mx_getcode.test.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mx_createwebservice.sas
  @li mx_getcode.sas
  @li mx_testservice.sas

**/

/* first create a service */

%let item=%mf_uid();;

%global test1;
%let test1=FAIL;

filename ft15f001 temp;
parmcards4;
  %let test1=SUCCESS;
;;;;
%mx_createwebservice(path=&mcTestAppLoc/temp,name=&item)

%mx_getcode(&mcTestAppLoc/temp/&item,testref1)

%inc testref1/lrecl=1000;

%mp_assert(
  iftrue=(&test1=SUCCESS),
  desc=code was successfully fetched,
  outds=work.test_results
)
