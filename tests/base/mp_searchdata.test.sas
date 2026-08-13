/**
  @file
  @brief Testing mp_searchdata.sas

  <h4> SAS Macros </h4>
  @li mp_searchdata.sas
  @li mp_assert.sas


**/

/* SYSWARNINGTEXT is an automatic variable and cannot be modified, so
  capture the session start state (may contain a license expiry warning,
  which is an environment issue) and later assert nothing new was added */
%let initwarningtext=%superq(syswarningtext);

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

/* assert that mp_searchdata itself raised no new warnings */
%mp_assert(
  iftrue=("%superq(syswarningtext)"="%superq(initwarningtext)"),
  desc=Ensuring WARN status is clean,
  outds=work.test_results
)
