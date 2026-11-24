/**
  @file
  @brief Testing mp_assertcolvals macro

  <h4> SAS Macros </h4>
  @li mddl_assert.sas
  @li mp_assertcolvals.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas

**/


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

/* Failure rows are isolated from the suite results and must append intact. */
%mp_assertcolvals(sashelp.class.sex,
  checkvals=work.check.val, test=NOVAL,
  desc=Expected NOVAL failure, outds=work.colval_results)
%mp_assertcolvals(sashelp.class.sex,
  checkvals=work.check.val, test=ALLVALS,
  desc=Expected ALLVALS pass, outds=work.colval_results)
proc sql noprint;
  select count(*) into: ncolvalfail trimmed from work.colval_results
    where test_result='FAIL' and test_description='Expected NOVAL failure'
      and test_comments contains 'has 0/'
      and test_comments contains 'not in work.check.val';
  select count(*) into: ncolvalpass trimmed from work.colval_results
    where test_result='PASS' and test_description='Expected ALLVALS pass';
  select count(*) into: ncolvaltotal trimmed from work.colval_results;
quit;
%mp_assert(iftrue=(&ncolvalfail=1 and &ncolvalpass=1 and &ncolvaltotal=2),
  desc=Checking colvals FAIL details and appended PASS)

%mddl_assert(work.assert_schema)
%mp_assertmodel(work.colval_results,base=work.assert_schema,
  desc=Checking mp_assertcolvals output schema)
