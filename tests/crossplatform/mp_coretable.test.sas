/**
  @file
  @brief Testing mp_coretable.sas macro

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mp_coretable.sas
  @li mp_assert.sas

**/


%mp_coretable(LOCKTABLE,libds=work.lock)
%mp_assert(
  iftrue=(%mf_existds(work.lock)=1),
  desc=Lock table created,
  outds=work.test_results
)
%mp_coretable(LOCKTABLE)
%mp_assert(
  iftrue=("&syscc"="0"),
  desc=DDL export ran without errors,
  outds=work.test_results
)

%mp_coretable(FILTER_SUMMARY,libds=work.sum)
%mp_assert(
  iftrue=(%mf_existds(work.sum)=1),
  desc=Filter summary table created,
  outds=work.test_results
)