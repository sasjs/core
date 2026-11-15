/**
  @file
  @brief Testing mv_getgroupmembers macro
  @details The populated and unknown-group paths have fixtures here. The third
    path - a 200 whose items dataset carries no member columns, which is what an
    empty group answers - has no fixture: an empty group is an estate fact
    (creating one is refused with 403), so that branch is proven on a live
    estate only, against a stock group that happens to have no members.

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_getuser.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
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
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,providerId)>0),
  desc=Check the dataset carries a providerId column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,implicit)>0),
  desc=Check the dataset carries an implicit column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,type)>0),
  desc=Check the dataset carries a type column
)

/* a group id the server does not know - the macro answers with the documented
  columns and zero rows rather than one all-missing observation */
%mp_assertscope(SNAPSHOT)
%mv_getgroupmembers(group=no_such_group_sasjs_core, outds=work.unknown)
%mp_assertscope(COMPARE,
  desc=mv_getgroupmembers does not leak scope on an unknown group,
    ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN,
  outds=work.test_results
)
%mp_assertdsobs(work.unknown,
  desc=Check an unknown group returns no rows,
  test=EMPTY,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_existvar(work.unknown,providerId)>0),
  desc=Check the unknown-group listing carries a providerId column
)
%mp_assert(
  iftrue=(%mf_existvar(work.unknown,type)>0),
  desc=Check the unknown-group listing carries a type column
)
