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

%mp_assert(
  iftrue=("&SYSWARNINGTEXT" = ""),
  desc=Ensuring WARN status is clean,
  outds=work.test_results
)
