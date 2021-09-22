/**
  @file
  @brief Asserts the values in a column
  @details Useful in the context of writing sasjs tests.  The results of the
  test are _appended_ to the &outds. table.

  Example usage:

      data work.checkds;
        do checkval='Jane','James','Jill';
          output;
        end;
      run;
      %mp_assertcolvals(sashelp.class.name,
        checkvals=work.checkds.checkval,
        desc=At least one value has a match,
        test=ANYVAL
      )

      data work.check;
        do val='M','F';
          output;
        end;
      run;
      %mp_assertcolvals(sashelp.class.sex,
        checkvals=work.check.val,
        desc=All values have a match,
        test=ALLVALS
      )

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_nobs.sas
  @li mp_abort.sas


  @param [in] indscol The input library.dataset.column to test for values
  @param [in] checkvals= A library.dataset.column value containing a UNIQUE
    list of values to be compared against the source (indscol).
  @param [in] desc= (Testing observations) The user provided test description
  @param [in] test= (ALLVALS) The test to apply.  Valid values are:
    @li ALLVALS - Test is a PASS if ALL values have a match in checkvals
    @li ANYVAL - Test is a PASS if at least 1 value has a match in checkvals
  @param [out] outds= (work.test_results) The output dataset to contain the
  results.  If it does not exist, it will be created, with the following format:
  |TEST_DESCRIPTION:$256|TEST_RESULT:$4|TEST_COMMENTS:$256|
  |---|---|---|
  |User Provided description|PASS|Column &indscol contained ALL target vals|


  <h4> Related Macros </h4>
  @li mp_assertdsobs.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_assertcolvals(indscol,
  checkvals=0,
  test=ALLVALS,
  desc=mp_assertcolvals - no desc provided,
  outds=work.test_results
)/*/STORE SOURCE*/;

  %mp_abort(iftrue= (&syscc ne 0)
    ,mac=&sysmacroname
    ,msg=%str(syscc=&syscc - on macro entry)
  )

  %local lib ds col clib cds ccol nobs;
  %let lib=%scan(&indscol,1,%str(.));
  %let ds=%scan(&indscol,2,%str(.));
  %let col=%scan(&indscol,3,%str(.));
  %mp_abort(iftrue= (%mf_existds(&lib..&ds)=0)
    ,mac=&sysmacroname
    ,msg=%str(&lib..&ds not found!)
  )

  %mp_abort(iftrue= (&checkvals=0)
    ,mac=&sysmacroname
    ,msg=%str(Set CHECKVALS to a library.dataset.column containing check vals)
  )
  %let clib=%scan(&checkvals,1,%str(.));
  %let cds=%scan(&checkvals,2,%str(.));
  %let ccol=%scan(&checkvals,3,%str(.));
  %mp_abort(iftrue= (%mf_existds(&clib..&cds)=0)
    ,mac=&sysmacroname
    ,msg=%str(&clib..&cds not found!)
  )
  %let nobs=%mf_nobs(&clib..&cds);
  %mp_abort(iftrue= (&nobs=0)
    ,mac=&sysmacroname
    ,msg=%str(&clib..&cds is empty!)
  )

  %let test=%upcase(&test);

  %if &test ne ALLVALS and &test ne ANYVAL %then %do;
    %mp_abort(
      mac=&sysmacroname,
      msg=%str(Invalid test - &test)
    )
  %end;

  %local result orig;
  %let result=-1;
  %let orig=-1;
  proc sql noprint;
  select count(*) into: result
    from &lib..&ds
    where &col not in (
      select &ccol from &clib..&cds
    );
  select count(*) into: orig from &lib..&ds;
  quit;

  %local notfound;
  proc sql outobs=10 noprint;
  select distinct &col  into: notfound separated by ' '
    from &lib..&ds
    where &col not in (
      select &ccol from &clib..&cds
    );

  %mp_abort(iftrue= (&syscc ne 0)
    ,mac=&sysmacroname
    ,msg=%str(syscc=&syscc after macro query)
  )

  data;
    length test_description $256 test_result $4 test_comments $256;
    test_description=symget('desc');
    test_result='FAIL';
    test_comments="&sysmacroname: &lib..&ds..&col has &result values "
      !!"not in &clib..&cds..&ccol.. First 10 vals:"!!symget('notfound');
  %if &test=ANYVAL %then %do;
    if &result < &orig then test_result='PASS';
  %end;
  %else %if &test=ALLVALS %then %do;
    if &result=0 then test_result='PASS';
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

%mend mp_assertcolvals;