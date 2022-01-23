/**
  @file
  @brief Testing mp_getmaxvarlengths macro

  <h4> SAS Macros </h4>
  @li mp_getmaxvarlengths.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/


/* regular usage */
%mp_assertscope(SNAPSHOT)
%mp_getmaxvarlengths(sashelp.class,outds=work.myds)
%mp_assertscope(COMPARE,desc=checking scope leakage on mp_getmaxvarlengths)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs
)
%mp_assertdsobs(work.myds,
  desc=Has 5 records,
  test=EQUALS 5
)
data work.errs;
  set work.myds;
  if name='Name' and maxlen ne 7 then output;
  if name='Sex' and maxlen ne 1 then output;
  if name='Age' and maxlen ne 3 then output;
  if name='Height' and maxlen ne 8 then output;
  if name='Weight' and maxlen ne 3 then output;
run;
data _null_;
  set work.errs;
  putlog (_all_)(=);
run;

%mp_assertdsobs(work.errs,
  desc=Err table has 0 records,
  test=EQUALS 0
)

/* test2 */
data work.test2;
  length a 3 b 5;
  a=1/3;
  b=1/3;
  c=1/3;
  d=._;
  e=.;
  output;
  output;
run;
%mp_getmaxvarlengths(work.test2,outds=work.myds2)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs in second test (with nulls)
)
%mp_assertdsobs(work.myds2,
  desc=Has 5 records,
  test=EQUALS 5
)
data work.errs2;
  set work.myds2;
  if name='a' and maxlen ne 3 then output;
  if name='b' and maxlen ne 5 then output;
  if name='c' and maxlen ne 8 then output;
  if name='d' and maxlen ne 3 then output;
  if name='e' and maxlen ne 0 then output;
run;
data _null_;
  set work.errs2;
  putlog (_all_)(=);
run;

%mp_assertdsobs(work.errs2,
  desc=Err table has 0 records,
  test=EQUALS 0
)