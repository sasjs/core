/**
  @file
  @brief Testing mf_verifymacvars macro

  <h4> SAS Macros </h4>
  @li mf_verifymacvars.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%let var1=x;
%let var2=y;

%mp_assertscope(SNAPSHOT)
%mp_assert(
  iftrue=(%mf_verifymacvars(var1 var2)=1),
  desc=Checking macvars exist,
  outds=work.test_results
)
%mp_assertscope(COMPARE)


/* an mf_ macro returns a value rather than ending the step: a failure has to
  come back as 0, with the reason in the log, and must not abort */
%mp_assert(
  iftrue=(%mf_verifymacvars(nosuchvar_intentional)=0),
  desc=Checking a missing macvar returns 0,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking the failure path leaves syscc alone,
  outds=work.test_results
)
