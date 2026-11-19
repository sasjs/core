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
    "%mf_isint(123)"="1"
  ),
  desc=Checking a multi-digit integer,
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
    "%mf_isint(12a)"="0"
  ),
  desc=Reject letters in an integer,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_isint(-12a)"="0"
  ),
  desc=Reject letters after a minus sign,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_isint(-1)"="1"
  ),
  desc=Checking mf_isint(-1),
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_isint()"="0"
  ),
  desc=Checking mf_isint(),
  outds=work.test_results
)
