/**
  @file
  @brief Testing mf_getvarlen macro

  <h4> SAS Macros </h4>
  @li mf_getvarlen.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.varlen_test;
  length charvar $5 numvar 8;
  charvar='hello';
  numvar=1;
  output;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getvarlen(work.varlen_test,charvar);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getvarlen does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarlen(work.varlen_test,charvar)=5),
  desc=Checking the length of a character variable is returned,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarlen(work.varlen_test,numvar)=8),
  desc=Checking the length of a numeric variable is 8,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getvarlen(work.varlen_test,nosuchvar))=1),
  desc=Checking a variable that does not exist returns a blank,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getvarlen(work.no_such_dataset,charvar))=0),
  desc=Checking a dataset that cannot be opened returns nothing,
  outds=work.test_results
)
%let syscc=0;
