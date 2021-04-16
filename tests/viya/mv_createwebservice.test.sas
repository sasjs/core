/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mv_createwebservice.sas

**/

/**
  * Test Case 1
  * Send special char in a service
  */

filename testref temp;
data _null_;
  file testref;
  put '01'x;
run;
%mv_createwebservice(
  path=&mcTestAppLoc/tests/macros,
  code=testref,
  name=mv_createwebservice
)