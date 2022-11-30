/**
  @file
  @brief Testing mf_getgitbranch.sas macro

  <h4> SAS Macros </h4>
  @li mf_getgitbranch.sas
  @li mp_assert.sas

**/

/* grab core repo */
%let gitdir=%sysfunc(pathname(work))/core;
%let repo=https://github.com/sasjs/core;
%put source clone rc=%sysfunc(GITFN_CLONE(&repo,&gitdir));

%mp_assert(
  iftrue=(%mf_getgitbranch(&gitdir)=main),
  desc=Checking correct branch was obtained,
  outds=work.test_results
)
