/**

  @file
  @brief Testing mp_assert macro
  @details The results dataset is shared.  Packages built on these assertion
  macros append their own statuses to work.test_results, and a status can be
  longer than PASS or FAIL - CHECK, for example, is used to flag an item for
  review.  When such a package appends to a results dataset created with a
  shorter column, PROC APPEND refuses the rows outright:

    WARNING: Variable test_result has different lengths on BASE and DATA files
    ERROR: No appending done because of anomalies listed above.

  so the column must be wide enough for the longer status.

  <h4> SAS Macros </h4>
  @li mp_assert.sas

**/

/* create the results dataset with the assertion macros, as any test does */
%mp_assert(
  iftrue=(1=1),
  desc=Checking result was created,
  outds=work.test_results
)

/* a downstream package appends its own 5 character status */
data work.append_test;
  length test_result $5 test_description $256 test_comments $256;
  test_result='CHECK';
  test_description='Checking a 5 character status survives the append';
  test_comments='Simulates a downstream package appending to the results';
run;

proc append base=work.test_results data=work.append_test;
run;

/* a refused append leaves the session in syntax check mode (OBS=0), which
  would silently skip the assertions below - reset it so the problem is
  reported instead of hidden */
options obs=max;

%let checkval=;
%let checklen=0;
data _null_;
  set work.test_results;
  if test_result='CHECK' then do;
    call symputx('checkval',test_result);
    call symputx('checklen',lengthc(test_result));
  end;
run;

%mp_assert(
  iftrue=("&checkval"="CHECK"),
  desc=Checking a 5 character status is not refused by the append
)

%mp_assert(
  iftrue=(&checklen=5),
  desc=Checking the results column holds a 5 character status
)
