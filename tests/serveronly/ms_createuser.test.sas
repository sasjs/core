/**
  @file
  @brief Testing ms_createuser.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_createuser.sas
  @li ms_getusers.sas

**/

%let user=%substr(%mf_getuniquename(),1,8);

%mp_assertscope(SNAPSHOT)
%ms_createuser(&user,passwrd,outds=test1,mdebug=&sasjs_mdebug)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN
)

%let id=0;
data _null_;
  set work.test1;
  call symputx('id',id);
  putlog (_all_)(=);
run;
%mp_assert(
  iftrue=(&id>0),
  desc=Checking that user was created with an ID,
  outds=work.test_results
)

/* double check by querying the list of users */
%ms_getusers(outds=work.test2)
%let checkid=0;
data _null_;
  set work.test2;
  if _n_<20 then putlog (_all_)(=);
  if upcase(username)="%upcase(&user)";
  call symputx('checkid',id);
run;
%mp_assert(
  iftrue=(&checkid=&id),
  desc=Checking that fetched user exists and has the same ID,
  outds=work.test_results
)





