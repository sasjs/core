/**
  @file
  @brief Asserts the number of observations in a dataset
  @details Useful in the context of writing sasjs tests.  The results of the
  test are _appended_ to the &outds. table.

  Example usage:

      %mp_assertdsobs(sashelp.class) %* tests if any observations are present;

  <h4> SAS Macros </h4>
  @li mf_nobs.sas


  @param [in] inds input dataset to test for presence of observations
  @param [in] desc= (Testing observations) The user provided test description
  @param [in] test= (HASOBS) The test to apply.  Valid values are:
    @li HASOBS Test is a PASS if the input dataset has any observations
    @li EMPTY Test is a PASS if input dataset is empty
  @param [out] outds= (work.test_results) The output dataset to contain the
  results.  If it does not exist, it will be created, with the following format:
  |TEST_DESCRIPTION:$256|TEST_RESULT:$4|TEST_COMMENTS:$256|
  |---|---|---|
  |User Provided description|PASS|Dataset &inds has XX obs|


  @version 9.2
  @author Allan Bowe

**/

%macro mp_assertdsobs(inds,
  test=HASOBS,
  desc=Testing observations,
  outds=work.test_results
)/*/STORE SOURCE*/;

  %local nobs;
  %let nobs=%mf_nobs(&inds);
  %let test=%upcase(&test);

  data;
    length test_description $256 test_result $4 test_comments $256;
    test_description=symget('desc');
    test_result='FAIL';
    test_comments="&sysmacroname: Dataset &inds has &nobs observations";
  %if &test=HASOBS %then %do;
    if &nobs>0 then test_result='PASS';
  %end;
  %else %if &test=EMPTY %then %do;
    if &nobs=0 then test_result='PASS';
  %end;
  %else %do;
    test_comments="&sysmacroname: Unsatisfied test condition - &test";
  %end;
  run;

  %local ds;
  %let ds=&syslast;

  proc append base=&outds data=&ds;
  run;

  proc sql;
  drop table &ds;

%mend;