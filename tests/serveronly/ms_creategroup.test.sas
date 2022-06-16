/**
  @file
  @brief Testing ms_creategroup.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_creategroup.sas
  @li ms_getgroups.sas

**/

%let group=%substr(%mf_getuniquename(),1,8);

%mp_assertscope(SNAPSHOT)
%ms_creategroup(&group, desc=The description,mdebug=&sasjs_mdebug,outds=test1)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN
)

%let id=0;
data _null_;
  set work.test1;
  call symputx('id',groupid);
run;
%mp_assert(
  iftrue=(&id>0),
  desc=Checking that group was created with an ID,
  outds=work.test_results
)

/* double check by querying the list of users */
%ms_getgroups(outds=work.test2)
%let checkid=0;
data _null_;
  set work.test2;
  where upcase(name)="%upcase(&group)";
  call symputx('checkid',groupid);
run;
%mp_assert(
  iftrue=(&checkid=&id),
  desc=Checking that fetched group exists and has the same ID,
  outds=work.test_results
)





