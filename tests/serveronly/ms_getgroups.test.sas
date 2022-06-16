/**
  @file
  @brief Testing ms_getgroups.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li ms_adduser2group.sas
  @li ms_creategroup.sas
  @li ms_getgroups.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/

/* create a group */
%let group=%substr(%mf_getuniquename(),1,8);
%ms_creategroup(&group, desc=The description,mdebug=&sasjs_mdebug,outds=test1)

/* get groups */
%mp_assertscope(SNAPSHOT)
%ms_getgroups(outds=work.test1,mdebug=&sasjs_mdebug)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN
)

/* check the group was created */
%mp_assertdsobs(work.test1,test=ATLEAST 1)

%let test2=0;
%put &=group;
data _null_;
  set work.test1;
  putlog (_all_)(=);
  if upcase(name)="%upcase(&group)" then do;
    putlog "&group found!";
    call symputx('test2',1);
    call symputx('gid',groupid); /* used in next test */
  end;
run;

%mp_assert(
  iftrue=("&test2"="1"),
  desc=Checking group was created,
  outds=work.test_results
)


/* now check if the filter for the groups for a user works */

/* add a member */
%ms_adduser2group(uid=1,gid=&gid)

%ms_getgroups(user=secretuser,outds=work.test3)

%let test3=0;
data _null_;
  set work.test3;
  if groupid=&gid then call symputx('test3',1);
run;

%mp_assert(
  iftrue=("&test3"="1"),
  desc=Checking group list was returned for a user,
  outds=work.test_results
)
