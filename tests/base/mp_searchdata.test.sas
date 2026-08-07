/**
  @file
  @brief Testing mp_searchdata.sas

  <h4> SAS Macros </h4>
  @li mp_searchdata.sas
  @li mp_assert.sas


**/

/** Test 1 - generic useage */

%mp_searchdata(lib=sashelp, ds=class, string=a)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors in regular usage,
  outds=work.test_results
)

/** Test 2 - with obs issue  */

%mp_searchdata(lib=sashelp, ds=class, string=l,outobs=5)
%let warntxt=%str(&SYSWARNINGTEXT);
data _null_;
  length txt $200;
  txt=symget('SYSWARNINGTEXT');
  if txt=:'The Base SAS Software product with which DATASTEP is associated'!!
  ' will be expiring' then call symputx('warntxt','');
run;

%mp_assert(
  iftrue=("&warntxt" = ""),
  desc=Ensuring WARN status is clean,
  outds=work.test_results
)
