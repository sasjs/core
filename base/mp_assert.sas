/**
  @file
  @brief Generic assertion
  @details Useful in the context of writing sasjs tests.  The results of the
  test are _appended_ to the &outds. table.

  Example usage:

      %mp_assert(iftrue=(1=1),
        desc=Obviously true
      )

      %mp_assert(iftrue=(1=0),
        desc=Will fail
      )

  @param [in] iftrue= (1=1) A condition where, if true, the test is a PASS.
  Else, the test is a fail.

  @param [in] desc= (Testing observations) The user provided test description
  @param [out] outds= (work.test_results) The output dataset to contain the
  results.  If it does not exist, it will be created, with the following format:
  |TEST_DESCRIPTION:$256|TEST_RESULT:$4|TEST_COMMENTS:$256|
  |---|---|---|
  |User Provided description|PASS|Dataset &inds contained ALL columns|

  @version 9.2
  @author Allan Bowe

**/

%macro mp_assert(iftrue=(1=1),
  desc=0,
  outds=work.test_results
)/*/STORE SOURCE*/;

  data ;
    length test_description $256 test_result $4 test_comments $256;
    test_description=symget('desc');
    test_comments="&sysmacroname: Test result of "!!symget('iftrue');
  %if %eval(%unquote(&iftrue)) %then %do;
    test_result='PASS';
  %end;
  %else %do;
    test_result='FAIL';
  %end;
  run;

  %local ds ;
  %let ds=&syslast;
  proc append base=&outds data=&ds;
  run;
  proc sql;
  drop table &ds;

%mend mp_assert;