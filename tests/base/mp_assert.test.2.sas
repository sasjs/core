/**

  @file
  @brief Testing mp_assert macro
  @details Covers the failure path - mp_assert.test.sas only exercises a
  condition that is true.  The false condition is recorded against a separate
  results dataset so the suite does not count it as a failure; what is under
  test is that FAIL is written for it.

  <h4> SAS Macros </h4>
  @li mp_assert.sas

**/

%mp_assert(iftrue=(1=0),
  desc=Checking a false condition records FAIL,
  outds=work.neg_results
)

%mp_assert(iftrue=(1=1),
  desc=Checking a true condition records PASS,
  outds=work.neg_results
)

proc sql noprint;
  select count(*) into: nfail from work.neg_results
    where test_result='FAIL';
  select count(*) into: npass from work.neg_results
    where test_result='PASS';
quit;

%mp_assert(iftrue=(&nfail=1),
  desc=Checking the false condition recorded exactly one FAIL)

%mp_assert(iftrue=(&npass=1),
  desc=Checking the true condition recorded exactly one PASS)
