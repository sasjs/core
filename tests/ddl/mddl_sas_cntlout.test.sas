/**
  @file
  @brief mddl_sas_cntlout ddl test

  <h4> SAS Macros </h4>
  @li mddl_sas_cntlout.sas
  @li mf_existds.sas
  @li mp_assert.sas

**/

%mddl_sas_cntlout(libds=WORK.TEST)

%mp_assert(
  iftrue=(%mf_existds(WORK.TEST)=1),
  desc=Checking table was created,
  outds=work.test_results
)