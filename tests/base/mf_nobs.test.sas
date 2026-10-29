/**
  @file
  @brief Testing mf_nobs macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.nobs_test;
  do i=1 to 3;
    output;
  end;
run;

/* a dataset that exists but holds no observations */
data work.nobs_zero;
  x=1;
  stop;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_nobs(work.nobs_test);
%mp_assertscope(COMPARE,
  desc=Checking that mf_nobs does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.nobs_test)=3),
  desc=Checking the observation count of a populated dataset,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.nobs_zero)=0),
  desc=Checking that an empty dataset returns zero,
  outds=work.test_results
)
