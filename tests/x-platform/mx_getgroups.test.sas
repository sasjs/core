/**
  @file
  @brief Testing mx_getgroups.test.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mf_getuser.sas
  @li mp_assert.sas
  @li mx_getgroups.sas

**/


%mx_getgroups(outds=work.test1)

%mp_assert(
  iftrue=(%mf_nobs(work.test1)>0),
  desc=groups were found,
  outds=work.test_results
)

%mx_getgroups(outds=work.test2,user=%mf_getuser())

%mp_assert(
  iftrue=(%mf_nobs(work.test2)>0),
  desc=groups for current user were found,
  outds=work.test_results
)