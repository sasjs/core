/**
  @file
  @brief Testing the SAS 9 metadata group model

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li mf_getuser.sas
  @li mf_nobs.sas
  @li mm_getgroups.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

%mddl_getgroups(work.groupmodel)

%mp_assertscope(SNAPSHOT)
%mm_getgroups(outds=work.groups)
%mp_assertscope(COMPARE,
  desc=mm_getgroups does not leak macro variables)
%mp_assertmodel(work.groups,base=work.groupmodel,key=groupuri,
  desc=Metadata group model and identifiers)
%mp_assert(iftrue=(%mf_nobs(work.groups)>0),
  desc=Metadata group list is not empty)

%mp_assertscope(SNAPSHOT)
%mm_getgroups(user=%mf_getuser(),outds=work.usergroups)
%mp_assertscope(COMPARE,
  desc=mm_getgroups user filter does not leak macro variables)
%mp_assertmodel(work.usergroups,base=work.groupmodel,key=groupuri,
  desc=Metadata user group model and identifiers)

proc sql noprint;
  select count(*) into :missing_groups trimmed
  from work.usergroups as u
  where not exists (select * from work.groups as a
    where a.groupuri=u.groupuri and a.groupname=u.groupname);
quit;
%mp_assert(iftrue=(&missing_groups=0),
  desc=User group identifiers and names match the group list)
