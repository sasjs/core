/**
  @file
  @brief Testing mp_assertdsobs.sas macro

  <h4> SAS Macros </h4>
  @li mddl_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertmodel.sas
  @li mp_assertcolvals.sas

**/


data work.somedata;
  do x=1 to 15;
    output;
  end;
run;

%mp_assertdsobs(work.somedata,
  test=ATLEAST 15,
  outds=work.test_the_test
)

%mp_assertdsobs(work.somedata,
  test=ATMOST 15,
  outds=work.test_the_test
)

data work.check;
  val='PASS';
run;
%mp_assertcolvals(work.test_the_test.test_result,
  checkvals=work.check.val,
  desc=Testing ATLEAST / ATMOST for passes,
  test=ALLVALS
)

%mp_assertdsobs(work.somedata,
  test=ATLEAST 16,
  outds=work.test_the_test2
)
%mp_assertdsobs(work.somedata,
  test=ATMOST 14,
  outds=work.test_the_test2
)

data _null_;
  set work.test_the_test2;
  putlog (_all_)(=);
run;

data work.check2;
  val='FAIL';
run;
%mp_assertcolvals(work.test_the_test2.test_result,
  checkvals=work.check2.val,
  desc=Testing ATLEAST / ATMOST for failures,
  test=ALLVALS
)



%mddl_assert(work.assert_schema)
%mp_assertmodel(work.test_the_test,base=work.assert_schema,
  desc=Checking mp_assertdsobs output schema)
