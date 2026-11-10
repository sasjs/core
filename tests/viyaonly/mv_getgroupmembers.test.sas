/**
  @file
  @brief Testing mv_getgroupmembers macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_getuser.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_getgroupmembers.sas
  @li mv_getusergroups.sas

**/

/* the group is one the current user belongs to, so it is guaranteed to have
  at least that member - an empty group makes the macro's data step fail */
%mv_getusergroups(user=%mf_getuser(), outds=work.mygroups)
data _null_;
  set work.mygroups(obs=1);
  call symputx('groupid',id,'l');
run;

%mp_assertscope(SNAPSHOT)
%mv_getgroupmembers(group=&groupid, outds=work.groupmembers)
%mp_assertscope(COMPARE,
  desc=mv_getgroupmembers does not leak scope,
    ignorelist=MC0_JADVLEN,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.groupmembers))=1),
  desc=Check the group members dataset was created
)
%mp_assert(
  iftrue=(%mf_nobs(work.groupmembers)>0),
  desc=Check the group has at least one member
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,id)>0),
  desc=Check the dataset carries an id column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,name)>0),
  desc=Check the dataset carries a name column
)
