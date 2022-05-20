/**
  @file
  @brief Testing mp_assert macro
  @details This is quite "meta".. it's just testing itself

  <h4> SAS Macros </h4>
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(1=1),
  desc=Checking result was created,
  outds=work.test_results
)
