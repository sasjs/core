/**
  @file
  @brief Testing mv_getusergroups macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_getuser.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_getusergroups.sas

**/

%mp_assertscope(SNAPSHOT)
%mv_getusergroups(user=%mf_getuser(), outds=work.usergroups)
%mp_assertscope(COMPARE,
  desc=mv_getusergroups does not leak scope,
    ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.usergroups))=1),
  desc=Check the user groups dataset was created
)
%mp_assert(
  iftrue=(%mf_nobs(work.usergroups)>0),
  desc=Check the user belongs to at least one group
)
%mp_assert(
  iftrue=(%mf_existvar(work.usergroups,id)>0),
  desc=Check the dataset carries an id column
)
