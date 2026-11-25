/**
  @file
  @brief Test the cross-platform group model and memberships

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuser.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas
  @li mx_getgroups.sas

**/

data work.groupmodel;
  length groupuri groupname groupdesc $256;
  stop;
run;

%mp_assertscope(SNAPSHOT)
%mx_getgroups(outds=work.allgroups)
%mp_assertscope(COMPARE,
  desc=All groups does not leak macro variables,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
    MC1_JADP1LEN MC1_JADP2LEN MC1_JADP3LEN MC1_JADPNUM MC1_JADVLEN,
  outds=work.test_results
)
%mp_assertmodel(work.allgroups,base=work.groupmodel,key=groupuri,
  desc=All groups model and identifiers)
%mp_assert(iftrue=(%mf_nobs(work.allgroups)>0),
  desc=All groups are not empty)

%mp_assertscope(SNAPSHOT)
%mx_getgroups(outds=work.usergroups,user=%mf_getuser())
%mp_assertscope(COMPARE,
  desc=User groups does not leak macro variables,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
    MC1_JADP1LEN MC1_JADP2LEN MC1_JADP3LEN MC1_JADPNUM MC1_JADVLEN
    MC2_JADP1LEN MC2_JADP2LEN MC2_JADP3LEN MC2_JADPNUM MC2_JADVLEN,
  outds=work.test_results
)
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
