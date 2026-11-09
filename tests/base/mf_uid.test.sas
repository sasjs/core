/**
  @file
  @brief Testing mf_uid macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%let today=%sysfunc(today(),yymmddn8.);

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_uid();
%mp_assertscope(COMPARE,
  desc=Checking that mf_uid does not leak scope,
  outds=work.test_results
)

%let uid1=%mf_uid();
%let uid2=%mf_uid();

%mp_assert(
  iftrue=(%substr(&uid1,1,8)=&today),
  desc=Checking that the uid starts with the yymmddn8 form of today,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(countw(&uid1,_))=4),
  desc=Checking that the uid has four underscore separated parts,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(&uid1)>=20),
  desc=Checking that the uid is long enough to carry a timestamp and a job id,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&uid1 ne &uid2),
  desc=Checking that two calls return different uids,
  outds=work.test_results
)
