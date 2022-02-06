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

