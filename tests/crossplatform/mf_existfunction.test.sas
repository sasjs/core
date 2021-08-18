/**
  @file
  @brief Testing mf_existfunction macro

  <h4> SAS Macros </h4>
  @li mf_existfunction.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(%mf_existfunction(CAT)=1),
  desc=Checking if CAT function exists,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existfunction(DOG)=0),
  desc=Checking DOG function does not exist,
  outds=work.test_results
)

