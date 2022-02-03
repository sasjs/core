/**
  @file
  @brief term file for tests

  <h4> SAS Macros </h4>
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking final error condition,
  outds=work.test_results
)


%webout(OPEN)
%webout(OBJ, TEST_RESULTS)
%webout(CLOSE)