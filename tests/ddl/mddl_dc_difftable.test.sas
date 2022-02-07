/**
  @file
  @brief Difftable DDL test

  <h4> SAS Macros </h4>
  @li mddl_dc_difftable.sas
  @li mf_existds.sas
  @li mp_assert.sas

**/


%mddl_dc_difftable(libds=WORK.DIFFTABLE)

%mp_assert(
  iftrue=(%mf_existds(WORK.DIFFTABLE)=1),
  desc=Checking table was created,
  outds=work.test_results
)