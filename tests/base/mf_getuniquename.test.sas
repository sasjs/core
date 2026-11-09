/**
  @file
  @brief Testing mf_getuniquename macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas

**/

%let name1=%mf_getuniquename();
%let name2=%mf_getuniquename();
%let name3=%mf_getuniquename(prefix=XX);
%let dashpos=%sysfunc(index(&name1,-));

%mp_assert(
  iftrue=(%length(&name1)=32),
  desc=Checking the name is 32 characters long,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%substr(&name1,1,2)=MC),
  desc=Checking the default prefix is MC,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%substr(&name3,1,2)=XX),
  desc=Checking a supplied prefix is used,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(&name3)=32),
  desc=Checking the name stays 32 characters with a prefix,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&name1 ne &name2),
  desc=Checking two calls return different names,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&dashpos=0),
  desc=Checking the name contains no hyphen so it is a valid SAS name,
  outds=work.test_results
)
