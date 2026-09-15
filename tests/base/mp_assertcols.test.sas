/**

  @file
  @brief Testing mp_assertcols macro
  @details Covers each of the three test conditions (ALL, ANY, NONE), both
  satisfied and unsatisfied.  The unsatisfied cases are recorded against a
  separate results dataset so the suite does not count them as failures -
  what is under test is that the macro writes FAIL for them.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertcols.sas

**/

/* satisfied conditions */
%mp_assertcols(sashelp.class,
  cols=name age sex,
  test=ALL,
  desc=Checking ALL is satisfied when every column exists
)

%mp_assertcols(sashelp.class,
  cols=name weight,
  test=ANY,
  desc=Checking ANY is satisfied when one column exists
)

%mp_assertcols(sashelp.class,
  cols=notacol othercol,
  test=NONE,
  desc=Checking NONE is satisfied when no column exists
)

/* unsatisfied conditions */
%mp_assertcols(sashelp.class,
  cols=name age weight,
  test=ALL,
  desc=Checking ALL is unsatisfied when a column is missing,
  outds=work.neg_results
)

%mp_assertcols(sashelp.class,
  cols=notacol othercol,
  test=ANY,
  desc=Checking ANY is unsatisfied when no column exists,
  outds=work.neg_results
)

%mp_assertcols(sashelp.class,
  cols=name height,
  test=NONE,
  desc=Checking NONE is unsatisfied when a column exists,
  outds=work.neg_results
)

proc sql noprint;
  select count(*) into: pos_fail from work.test_results
    where test_result ne 'PASS';
  select count(*) into: neg_pass from work.neg_results
    where test_result ne 'FAIL';
quit;

%mp_assert(iftrue=(&pos_fail=0),
  desc=Checking the satisfied conditions all recorded PASS)

%mp_assert(iftrue=(&neg_pass=0),
  desc=Checking the unsatisfied conditions all recorded FAIL)
