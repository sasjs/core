/**
  @file
  @brief Testing mf_getuniquefileref macro

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    "%substr(%mf_getuniquefileref(),1,1)"="#"
  ),
  desc=Checking for a temp fileref,
  outds=work.test_results
)
