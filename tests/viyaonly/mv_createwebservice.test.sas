/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mv_createwebservice.sas
  @li mv_getjobcode.sas

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
%put TEST1: creating web service;
%mv_createwebservice(
  path=&mcTestAppLoc/temp/macros,
  name=mv_createwebservice,
  code=testref
)
%put TEST1: fetching web service code;
%mv_getjobcode(
  path=&mcTestAppLoc/temp/macros,
  name=mv_createwebservice,
  outref=compare
)
%put TEST1: checking web service code;
data work.test_results;
  length test_description $256 test_result $4 test_comments $256;
  if _n_=1 then call missing (of _all_);
  infile compare end=eof;
  input;
  if eof then do;
    if _infile_='01'x then test_result='PASS';
    else test_result='FAIL';
    test_description="Creating web service with invisible character";
    output;
    stop;
  end;
run;