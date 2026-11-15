/**
  @file
  @brief Testing mx_createwebservice macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mx_createwebservice.sas
  @li mx_getcode.sas

**/

%let path=&mcTestAppLoc/mx_createwebservice;
%let name=%mf_uid();

%global test1;
%let test1=FAIL;

filename ft15f001 temp;
parmcards4;
  %let test1=SUCCESS;
;;;;

%mp_assertscope(SNAPSHOT)
%mx_createwebservice(path=&path, name=&name)
%mp_assertscope(COMPARE,
  desc=mx_createwebservice does not leak scope,
  outds=work.test_results
)

/* the artefact is the service, so read it back and run it: a dispatch that
  returned cleanly having written nothing would leave test1 at FAIL */
%mx_getcode(&path/&name, outref=testref1)
%inc testref1/lrecl=1000;

%mp_assert(
  iftrue=(&test1=SUCCESS),
  desc=Check the service was created and carries the supplied code
)
