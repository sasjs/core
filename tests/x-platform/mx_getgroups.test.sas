/**
  @file
  @brief Test the cross-platform group model and memberships

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li mf_getplatform.sas
  @li mf_getuser.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas
  @li mx_getgroups.sas

**/

/* JSON engine globals depend on the libref allocated in this session. */
%macro group_scope_compare(desc=);
  %local json_globals;
  %let json_globals=;
  proc sql noprint;
    select distinct name into :json_globals separated by ' '
    from dictionary.macros
    where scope='GLOBAL' and prxmatch(
      '/^MC(\d{1,6}|LIB\d{1,3})_JAD(P\d+LEN|PNUM|VLEN)$/i',strip(name));
  quit;
  %mp_assertscope(COMPARE,ignorelist=&json_globals
    ,desc=&desc,outds=work.test_results)
%mend group_scope_compare;

%mddl_getgroups(work.groupmodel)

%mp_assertscope(SNAPSHOT)
%mx_getgroups(outds=work.allgroups)
%group_scope_compare(desc=All groups does not leak macro variables)
%mp_assertmodel(work.allgroups,base=work.groupmodel,key=groupuri,
  desc=All groups model and identifiers)
%mp_assert(iftrue=(%mf_nobs(work.allgroups)>0),
  desc=All groups are not empty)

%mp_assertscope(SNAPSHOT)
%mx_getgroups(outds=work.usergroups,user=%mf_getuser())
%group_scope_compare(desc=User groups does not leak macro variables)
%mp_assertmodel(work.usergroups,base=work.groupmodel,key=groupuri,
  desc=User groups model and identifiers)
%mp_assert(iftrue=(%mf_nobs(work.usergroups)>0),
  desc=Current user has groups)

/* Membership IDs and names must correspond to the all-groups list. */
proc sql noprint;
  select count(*) into :missing_groups trimmed
  from work.usergroups as u
  where not exists (select * from work.allgroups as a
    where a.groupuri=u.groupuri and a.groupname=u.groupname);
quit;
%mp_assert(iftrue=(&missing_groups=0),
  desc=Membership identifiers and names match the group list)

%macro mx_empty_user_test();
  %if %mf_getplatform()=SASVIYA %then %do;
    %mx_getgroups(user=nosuchuser7394,outds=work.no_groups)
    %mp_assertmodel(work.no_groups,base=work.groupmodel,key=groupuri,
      desc=Unknown Viya user has the group model)
    %mp_assert(iftrue=(%mf_nobs(work.no_groups)=0),
      desc=Unknown Viya user has no groups)
  %end;
%mend mx_empty_user_test;
%mx_empty_user_test()
