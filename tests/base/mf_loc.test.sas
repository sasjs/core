/**
  @file
  @brief Testing mf_loc macro

  <h4> SAS Macros </h4>
  @li mf_loc.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_loc(VIYACONFIG);
%mp_assertscope(COMPARE,
  desc=Checking that mf_loc does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%index(%mf_loc(VIYACONFIG),/opt/sas/viya/config)=1),
  desc=Checking that the Viya configuration path is returned for VIYACONFIG,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%index(%mf_loc(POF),SASPlatformObjectFramework)>0),
  desc=Checking that the platform object framework is located for POF,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%index(%mf_loc(PLATFORMOBJECTFRAMEWORK),SASPlatform)>0),
  desc=Checking that the long form of POF is accepted,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_loc(NOSUCHITEM))=0),
  desc=Checking that an item the macro cannot locate returns nothing,
  outds=work.test_results
)
