/**
  @file
  @brief Testing mp_gitlog.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_gitlog.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* grab core repo */
%let gitdir=%sysfunc(pathname(work))/core;
%let repo=https://github.com/sasjs/core;
%put source clone rc=%sysfunc(GITFN_CLONE(&repo,&gitdir));

%mp_assertscope(SNAPSHOT)
%mp_gitlog(&gitdir,outds=work.test1)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Regular test works,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.test1)>1000),
  desc=output has gt 1000 rows,
  outds=work.test_results
)
