/**
  @file
  @brief Testing mf_existvarlist macro

  <h4> SAS Macros </h4>
  @li mf_existvarlist.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.existvarlist_test;
  length alpha $4 beta 8;
  alpha='a';
  beta=1;
  output;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_existvarlist(work.existvarlist_test,alpha beta);
%mp_assertscope(COMPARE,
  desc=Checking that mf_existvarlist does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existvarlist(work.existvarlist_test,alpha beta)=1),
  desc=Checking that a list of existing variables returns 1,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existvarlist(work.existvarlist_test,alpha nosuchvar)=0),
  desc=Checking that a list with one missing variable returns 0,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existvarlist(work.existvarlist_test,ALPHA)=1),
  desc=Checking that variable matching is case insensitive,
  outds=work.test_results
)

/* a member that exists but holds no variables */
data work.existvarlist_empty;
run;

%mp_assert(
  iftrue=(%mf_existvarlist(work.existvarlist_empty,alpha)=0),
  desc=Checking that a dataset with no variables returns 0,
  outds=work.test_results
)

/* a missing member answers 0 without leaving a failed probe behind */
%let existvarlist_missing=%mf_existvarlist(work.no_such_dataset,alpha);
%let existvarlist_syserr=&syserr;

%mp_assert(
  iftrue=(&existvarlist_missing=0),
  desc=Checking that a dataset that does not exist returns 0,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&existvarlist_syserr=0),
  desc=Checking that a missing member leaves SYSERR untouched,
  outds=work.test_results
)

/* blank input answers 0 - the caller decides what to do about it */
%mp_assert(
  iftrue=(%mf_existvarlist(work.existvarlist_test,)=0),
  desc=Checking that a blank varlist returns 0,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existvarlist(,alpha)=0),
  desc=Checking that a blank libds returns 0,
  outds=work.test_results
)
