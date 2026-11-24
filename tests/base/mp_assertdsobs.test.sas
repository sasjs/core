/**
  @file
  @brief Testing mp_assertdsobs.sas macro

  <h4> SAS Macros </h4>
  @li mddl_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assert.sas
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

/* Do not change an existing USER libref. */
%macro test_user_noreplace();
  %local replace_option nuserpass;
  %if %sysfunc(libref(user))=0 %then %do;
    %put NOTE: Skipping USER library test because USER is already assigned.;
    %return;
  %end;
  %let replace_option=%sysfunc(getoption(replace));
  libname user "%sysfunc(pathname(work))";
  options noreplace;
  %mp_assertdsobs(work.somedata,test=EQUALS 15,
    desc=USER and NOREPLACE, outds=work.user_results)
  options &replace_option;
  libname user clear;
  %let nuserpass=0;
  %if %sysfunc(exist(work.user_results)) %then %do;
    proc sql noprint;
      select count(*) into: nuserpass trimmed from work.user_results
        where test_result='PASS' and test_description='USER and NOREPLACE';
    quit;
  %end;
  %mp_assert(iftrue=(&nuserpass=1),
    desc=Checking results with USER and NOREPLACE)
%mend test_user_noreplace;
%test_user_noreplace()
