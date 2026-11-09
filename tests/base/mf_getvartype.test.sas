/**
  @file
  @brief Testing mf_getvartype macro

  <h4> SAS Macros </h4>
  @li mf_getvartype.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* a zero length character variable cannot be built in SAS 9.4 - LENGTH
  x $0 is rejected with "The length of a character variable must be in the
  range of 1-32767" - so the shortest shape that can exist, a one byte blank,
  is what distinguishes a blank return from a real type */
data work.vartype_test;
  length charvar $5 numvar 8 blankvar $1;
  charvar='hello';
  numvar=1;
  blankvar='';
  output;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getvartype(work.vartype_test,charvar);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getvartype does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvartype(work.vartype_test,charvar)=C),
  desc=Checking a character variable returns C,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvartype(work.vartype_test,blankvar)=C),
  desc=Checking a character variable holding only a blank still returns C,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvartype(work.vartype_test,numvar)=N),
  desc=Checking a numeric variable returns N,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getvartype(work.vartype_test,nosuchvar))=1),
  desc=Checking a variable that does not exist returns a blank,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getvartype(work.no_such_dataset,charvar))=0),
  desc=Checking a dataset that cannot be opened returns nothing,
  outds=work.test_results
)
%let syscc=0;
