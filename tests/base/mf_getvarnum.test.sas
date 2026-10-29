/**
  @file
  @brief Testing mf_getvarnum macro

  <h4> SAS Macros </h4>
  @li mf_getvarnum.sas
  @li mf_isblank.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.varnum_test;
  length first $8 second 8 third $1;
  first='a';
  second=2;
  third='c';
  output;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getvarnum(work.varnum_test,first);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getvarnum does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarnum(work.varnum_test,first)=1),
  desc=Checking the first variable returns 1,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarnum(work.varnum_test,second)=2),
  desc=Checking the second variable returns 2,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarnum(work.varnum_test,third)=3),
  desc=Checking the third variable returns 3,
  outds=work.test_results
)

/* a variable that does not exist returns a blank */
%let varnum_missing=%mf_getvarnum(work.varnum_test,nosuchvar);

%mp_assert(
  iftrue=(%mf_isblank(&varnum_missing)=1),
  desc=Checking that a variable that does not exist returns blank,
  outds=work.test_results
)
