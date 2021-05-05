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
%mv_createwebservice(
  path=&mcTestAppLoc/temp/macros,
  code=testref,
  name=mv_createwebservice
)

filename compare temp;
%mv_getjobcode(
  path=&mcTestAppLoc/temp/macros
  ,name=mv_createwebservice
  ,outref=compare;
)

data test_results;
  length test_description $256 test_result $4 test_comments $256;
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