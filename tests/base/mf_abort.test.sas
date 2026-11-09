/**
  @file
  @brief Testing mf_abort macro

  <h4> SAS Macros </h4>
  @li mf_abort.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* The aborting path cannot be exercised from a test - ABORT ends the session
  and the runner would never report.  What is tested is the decision in front
  of it: a false condition must return without aborting. */

%mp_assertscope(SNAPSHOT)
%put scope check:
  %mf_abort(iftrue=%str(1=0),mac=mf_abort.test.sas,msg=not triggered);
%mp_assertscope(COMPARE,
  desc=Checking that mf_abort does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that a false comparison returns without aborting,
  outds=work.test_results
)

%mf_abort(iftrue=0,mac=mf_abort.test.sas,msg=not triggered)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that iftrue=0 returns without aborting,
  outds=work.test_results
)
