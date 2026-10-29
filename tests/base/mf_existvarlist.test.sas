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

%mp_assert(
  iftrue=(%mf_existvarlist(work.no_such_dataset,alpha)=0),
  desc=Checking that a dataset that cannot be opened returns 0,
  outds=work.test_results
)

/* the blank-parameter branch calls %mf_abort, so it stays uncovered: it ends
  the session, which is not something a test can assert (see mp_abort.test) */
