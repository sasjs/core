/**
  @file
  @brief Testing mf_isint macro

  <h4> SAS Macros </h4>
  @li mf_isint.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    "%mf_isint(1)"="1"
  ),
  desc=Checking basic mf_isint(1),
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_isint(1.1)"="0"
  ),
  desc=Checking basic mf_isint(1.1),
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_isint(-1)"="1"
  ),
  desc=Checking mf_isint(-1),
  outds=work.test_results
)