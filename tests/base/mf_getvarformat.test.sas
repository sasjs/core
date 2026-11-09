/**
  @file
  @brief Testing mf_getvarformat macro

  <h4> SAS Macros </h4>
  @li mf_getvarformat.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.varformat_test;
  length str1 $1 num1 8 str2 $10 num2 8;
  format str1 $1. num1 datetime19.;
  str1='a';
  num1=0;
  str2='hello mum!';
  num2=666;
  output;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getvarformat(work.varformat_test,str1);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getvarformat does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarformat(work.varformat_test,str1)=$1.),
  desc=Checking the format of a character variable is returned,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarformat(work.varformat_test,num1)=DATETIME19.),
  desc=Checking the format of a numeric variable is returned,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarformat(work.varformat_test,str2,force=1)=$10.),
  desc=Checking force=1 supplies a character default of the variable length,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getvarformat(work.varformat_test,num2,force=1)=best.),
  desc=Checking force=1 supplies a numeric default of best.,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getvarformat(work.varformat_test,nosuchvar))=0),
  desc=Checking a variable that does not exist returns nothing,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getvarformat(work.no_such_dataset,str1))=0),
  desc=Checking a dataset that cannot be opened returns nothing,
  outds=work.test_results
)
%let syscc=0;
