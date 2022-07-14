/**
  @file
  @brief Testing mf_increment macro

  <h4> SAS Macros </h4>
  @li mf_increment.sas
  @li mp_assert.sas

**/

%let var=0;

%mp_assert(
  iftrue=(
    "%mf_increment(var)"="1"
  ),
  desc=Checking basic mf_increment usage 1,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_increment(var)"="2"
  ),
  desc=Checking basic mf_increment usage 2,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_increment(var,incr=2)"="4"
  ),
  desc=Checking incr option,
  outds=work.test_results
)
