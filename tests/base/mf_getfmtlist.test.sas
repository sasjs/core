/**
  @file
  @brief Testing mf_getfmtlist macro

  <h4> SAS Macros </h4>
  @li mf_getfmtlist.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    "%mf_getfmtlist(sashelp.prdsale)"="DOLLAR $CHAR W MONNAME"
  ),
  desc=Checking basic numeric,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getfmtlist(sashelp.shoes)"="$CHAR BEST DOLLAR"
  ),
  desc=Checking basic char,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getfmtlist(sashelp.demographics)"="BEST Z $CHAR COMMA PERCENTN"
  ),
  desc=Checking longer numeric,
  outds=work.test_results
)