/**
  @file
  @brief Asserts the number of observations in a dataset
  @details Useful in the context of writing sasjs tests.  The results of the
  test are _appended_ to the &outds. table.

  Example usage:

      %mp_assertdsobs(sashelp.class) %* tests if any observations are present;

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_abort.sas


  @param [in] inds input dataset to test for presence of observations
  @param [in] desc= (Testing observations) The user provided test description
  @param [in] test= (HASOBS) The test to apply.  Valid values are:
    @li HASOBS - Test is a PASS if the input dataset has any observations
    @li EMPTY - Test is a PASS if input dataset is empty
    @li EQUALS [integer] - Test passes if row count matches the provided integer
    @LI ATLEAST [integer] - Test passes if row count is more than or equal to
      the provided integer
    @LI ATMOST [integer] - Test passes if row count is less than or equal to
      the provided integer
  @param [out] outds= (work.test_results) The output dataset to contain the
  results.  If it does not exist, it will be created, with the following format:
  |TEST_DESCRIPTION:$256|TEST_RESULT:$4|TEST_COMMENTS:$256|
  |---|---|---|
  |User Provided description|PASS|Dataset &inds has XX obs|

  <h4> Related Macros </h4>
  @li mp_assertcolvals.sas
  @li mp_assert.sas
  @li mp_assertcols.sas

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

  %if %substr(&test.xxxxx,1,6)=EQUALS %then %do;
    %let val=%scan(&test,2,%str( ));
    %mp_abort(iftrue= (%DATATYP(&val)=CHAR)
      ,mac=&sysmacroname
      ,msg=%str(Invalid test - &test, expected EQUALS [integer])
    )
    %let test=EQUALS;
  %end;
  %else %if %substr(&test.xxxxxxx,1,7)=ATLEAST %then %do;
    %let val=%scan(&test,2,%str( ));
    %mp_abort(iftrue= (%DATATYP(&val)=CHAR)
      ,mac=&sysmacroname
      ,msg=%str(Invalid test - &test, expected ATLEAST [integer])
    )
    %let test=ATLEAST;
  %end;
  %else %if %substr(&test.xxxxxxx,1,7)=ATMOST %then %do;
    %let val=%scan(&test,2,%str( ));
    %mp_abort(iftrue= (%DATATYP(&val)=CHAR)
      ,mac=&sysmacroname
      ,msg=%str(Invalid test - &test, expected ATMOST [integer])
    )
    %let test=ATMOST;
  %end;
  %else %if &test ne HASOBS and &test ne EMPTY %then %do;
    %mp_abort(
      mac=&sysmacroname,
      msg=%str(Invalid test - &test)
    )
  %end;

  data;
    length test_description $256 test_result $4 test_comments $256;
    test_description=symget('desc');
    test_result='FAIL';
    test_comments="&sysmacroname: Dataset &inds has &nobs observations.";
    test_comments=test_comments!!" Test was "!!symget('test');
  %if &test=HASOBS %then %do;
    if &nobs>0 then test_result='PASS';
  %end;
  %else %if &test=EMPTY %then %do;
    if &nobs=0 then test_result='PASS';
  %end;
  %else %if &test=EQUALS %then %do;
    if &nobs=&val then test_result='PASS';
  %end;
  %else %if &test=ATLEAST %then %do;
    if &nobs ge &val then test_result='PASS';
  %end;
  %else %if &test=ATMOST %then %do;
    if &nobs le &val then test_result='PASS';
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

%mend mp_assertdsobs;