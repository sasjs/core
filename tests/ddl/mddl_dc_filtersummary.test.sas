/**
  @file
  @brief Filtersummary DDL test

  <h4> SAS Macros </h4>
  @li mddl_dc_filtersummary.sas
  @li mf_existds.sas
  @li mp_assert.sas

**/

%mddl_dc_filtersummary(libds=WORK.TEST)

%mp_assert(
  iftrue=(%mf_existds(WORK.TEST)=1),
  desc=Checking table was created,
  outds=work.test_results
)