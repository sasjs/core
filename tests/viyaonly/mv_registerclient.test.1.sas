/**

  @file
  @brief Testing mv_registerclient.sas macro
  @details Tests for successful registration.  For this to work, the test
  account must be an admin.
​
  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assertcolvals.sas
  @li mv_registerclient.sas

**/

/**
  * Test Case 1
  */

%let id=%mf_getuniquename();
%let sec=%mf_getuniquename();
%mv_registerclient(client_id=&id,client_secret=&sec, outds=testds)

data work.checkds;
  id="&id";
  sec="&sec";
run;
%mp_assertcolvals(work.testds.client_id,
  checkvals=work.checkds.id,
  desc=Checking client id was created
  test=ALLVALS
)
%mp_assertcolvals(work.testds.client_secret,
  checkvals=work.checkds.sec,
  desc=Checking client secret was created
  test=ALLVALS
)