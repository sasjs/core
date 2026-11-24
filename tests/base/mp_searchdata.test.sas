/**
  @file
  @brief Testing mp_searchdata.sas

  <h4> SAS Macros </h4>
  @li mp_searchdata.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas


**/

/* SYSWARNINGTEXT is an automatic variable and cannot be modified, so
  capture the session start state (may contain a license expiry warning,
  which is an environment issue) and later assert nothing new was added */
%let initwarningtext=%superq(syswarningtext);

/** Test 1 - generic useage */

%mp_assertscope(SNAPSHOT)
%mp_searchdata(lib=sashelp, ds=class, string=a)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors in regular usage,
  outds=work.test_results
)
%mp_assertscope(COMPARE,
  desc=Search does not leak scope,
  outds=work.test_results
)
%mp_assertmodel(mpsearch.class,
  base=sashelp.class,
  key=name,
  desc=Search output model and key,
  outds=work.test_results
)
%mp_assertdsobs(mpsearch.class,
  test=EQUALS 9,
  desc=Search returns nine matches,
  outds=work.test_results
)

data work.search_nonmatches;
  set mpsearch.class;
  if index(name,'a')=0 and index(sex,'a')=0;
run;
%mp_assertdsobs(work.search_nonmatches,
  test=EMPTY,
  desc=All returned rows contain the search string,
  outds=work.test_results
)

/** Test 2 - with obs issue  */

%mp_searchdata(lib=sashelp, ds=class, string=l,outobs=5)

/* assert that mp_searchdata itself raised no new warnings */
%mp_assert(
  iftrue=("%superq(syswarningtext)"="%superq(initwarningtext)"),
  desc=Ensuring WARN status is clean,
  outds=work.test_results
)
