/**
  @file
  @brief Asserts the existence (or not) of columns
  @details Useful in the context of writing sasjs tests.  The results of the
  test are _appended_ to the &outds. table.

  Example usage:

      %mp_assertcols(sashelp.class,
        cols=name age sex,
        test=ALL,
        desc=check all columns exist
      )

      %mp_assertcols(sashelp.class,
        cols=a b c,
        test=NONE
      )

      %mp_assertcols(sashelp.class,
        cols=age depth,
        test=ANY
      )

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_existvarlist.sas
  @li mf_getvarlist.sas
  @li mf_wordsinstr1butnotstr2.sas
  @li mp_abort.sas


  @param [in] inds The input library.dataset to test for values
  @param [in] cols= The list of columns to check for
  @param [in] desc= (Testing observations) The user provided test description
  @param [in] test= (ALL) The test to apply.  Valid values are:
    @li ALL - Test is a PASS if ALL columns exist in &inds
    @li ANY - Test is a PASS if ANY of the columns exist in &inds
    @li NONE - Test is a PASS if NONE of the columns exist in &inds
  @param [out] outds= (work.test_results) The output dataset to contain the
  results.  If it does not exist, it will be created, with the following format:
  |TEST_DESCRIPTION:$256|TEST_RESULT:$4|TEST_COMMENTS:$256|
  |---|---|---|
  |User Provided description|PASS|Column &inds contained ALL columns|


  <h4> Related Macros </h4>
  @li mp_assertdsobs.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_assertcols(inds,
  cols=0,
  test=ALL,
  desc=0,
  outds=work.test_results
)/*/STORE SOURCE*/;

  %mp_abort(iftrue= (&syscc ne 0)
    ,mac=&sysmacroname
    ,msg=%str(syscc=&syscc - on macro entry)
  )

  %local lib ds ;
  %let lib=%scan(&inds,1,%str(.));
  %let ds=%scan(&inds,2,%str(.));
  %let cols=%upcase(&cols);

  %mp_abort(iftrue= (%mf_existds(&lib..&ds)=0)
    ,mac=&sysmacroname
    ,msg=%str(&lib..&ds not found!)
  )

  %mp_abort(iftrue= (&cols=0)
    ,mac=&sysmacroname
    ,msg=%str(No cols provided)
  )


  %let test=%upcase(&test);

  %if &test ne ANY and &test ne ALL and &test ne NONE %then %do;
    %mp_abort(
      mac=&sysmacroname,
      msg=%str(Invalid test - &test)
    )
  %end;

  /**
    * now do the actual test!
    */
  %local result;
  %if %mf_existVarList(&inds,&cols)=1 %then %let result=ALL;
  %else %do;
    %local targetcols compare;
    %let targetcols=%upcase(%mf_getvarlist(&inds));
    %let compare=%mf_wordsinstr1butnotstr2(
        Str1=&cols,
        Str2=&targetcols
      );
    %if %cmpres(&compare)=%cmpres(&cols) %then %let result=NONE;
    %else %let result=SOME;
  %end;

  data;
    length test_description $256 test_result $4 test_comments $256;
    test_description=symget('desc');
    if test_description='0'
    then test_description="Testing &inds for existence of &test of: &cols";

    test_result='FAIL';
    test_comments="&sysmacroname: &inds has &result columns ";
  %if &test=ALL %then %do;
    %if &result=ALL %then %do;
      test_result='PASS';
    %end;
  %end;
  %else %if &test=ANY %then %do;
    %if &result=SOME %then %do;
      test_result='PASS';
    %end;
  %end;
  %else %if &test=NONE %then %do;
    %if &result=NONE %then %do;
      test_result='PASS';
    %end;
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

%mend mp_assertcols;