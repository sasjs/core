/**
  @file
  @brief Testing ms_getusers.sas macro

  <h4> SAS Macros </h4>
  @li ms_creategroup.sas
  @li ms_adduser2group.sas
  @li ms_getusers.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/


%mp_assertscope(SNAPSHOT)
%ms_getusers(outds=work.test1,mdebug=&sasjs_mdebug)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN
)

%mp_assertdsobs(work.test1,test=ATLEAST 1)

/**
  * test the extraction of group members
  */

/* create a group */
%let group=%substr(%mf_getuniquename(),1,8);
%ms_creategroup(&group, desc=some desc,mdebug=&sasjs_mdebug,outds=work.group)
%let gid=0;
data _null_;
  set work.group;
  call symputx('gid',groupid);
run;

/* add a member */
%ms_adduser2group(uid=1,gid=&gid)

/* extract the members */
%ms_getusers(group=&group,outds=test2)

/* check the user is in the output list */
%let checkid=0;
data _null_;
  set work.test2;
  if id=1 then call symputx('checkid',1);
run;
%mp_assert(
  iftrue=(&checkid=1),
  desc=Checking that admin user was created in the new group,
  outds=work.test_results
)






