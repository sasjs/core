/**
  @file
  @brief Testing ms_adduser2group.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_adduser2group.sas
  @li ms_creategroup.sas

**/

/* first, create an empty group */
%let group=%substr(%mf_getuniquename(),1,8);
%ms_creategroup(&group, desc=The description,mdebug=&sasjs_mdebug,outds=test1a)
%let groupid=0;
data _null_;
  set work.test1a;
  call symputx('groupid',groupid);
run;
%mp_assert(
  iftrue=(&groupid>0),
  desc=Checking that group was created with an ID,
  outds=work.test_results
)

/* now add a user (user 1 always exists) */


%mp_assertscope(SNAPSHOT)
%ms_adduser2group(uid=1,gid=&groupid,mdebug=&sasjs_mdebug,outds=test1)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN
)

/* check the user is in the output list */
%let checkid=0;
data _null_;
  set work.test1;
  if id=1 then call symputx('checkid',1);
run;
%mp_assert(
  iftrue=(&checkid=1),
  desc=Checking that user was created in the new group,
  outds=work.test_results
)





