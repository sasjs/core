/**
  @file
  @brief Testing mp_testjob macro

  <h4> SAS Macros </h4>
  @li mp_testjob.sas
  @li mp_assert.sas

**/

%let t0=%sysfunc(datetime());
%mp_testjob(duration=5)
%let elapsed=%sysfunc(intck(second,&t0,%sysfunc(datetime())));

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that the timed job runs to completion,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&elapsed>=5 and &elapsed<180),
  desc=Checking that it runs for at least the requested duration,
  outds=work.test_results
)
