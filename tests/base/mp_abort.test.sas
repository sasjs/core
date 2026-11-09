/**
  @file
  @brief Testing mp_abort macro

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

  @details The aborting path cannot be exercised from a test - it ends the
  session - so the assertions cover the decision in front of it.

**/

%mp_assertscope(SNAPSHOT)
%put scope check:
  %mp_abort(iftrue=%str(1=0),mac=mp_abort.test.sas,msg=not triggered);
%mp_assertscope(COMPARE,
  desc=Checking that mp_abort does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that a false comparison returns without aborting,
  outds=work.test_results
)

%mp_abort(iftrue=0)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that iftrue=0 returns without aborting,
  outds=work.test_results
)

/* mode=INCLUDE reads the abort record dataset; a row with iftrue='1=0' is the
  state the branch exists for, and must return quietly */
data work.mp_abort_errds;
  length msg mac $1000;
  call missing(msg,mac);
  iftrue='1=0';
run;
%mp_abort(mode=INCLUDE)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that mode=INCLUDE returns when nothing has aborted,
  outds=work.test_results
)
