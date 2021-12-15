/**
  @file
  @brief Testing mf_getfmtname macro

  <h4> SAS Macros </h4>
  @li mf_getfmtname.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    "%mf_getfmtname(8.)"="W"
  ),
  desc=Checking basic numeric,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getfmtname($4.)"="$CHAR"
  ),
  desc=Checking basic char,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getfmtname(comma14.10)"="COMMA"
  ),
  desc=Checking longer numeric,
  outds=work.test_results
)