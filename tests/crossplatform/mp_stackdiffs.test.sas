/**
  @file
  @brief Testing mp_storediffs macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas
  @li mp_stackdiffs.sas
  @li mp_storediffs.sas

**/

/* first, make some data */

data work.orig work.deleted work.changed work.appended;
  set sashelp.electric;
  if _n_ le 10 then do;
    output work.deleted;
  end;
  else if _n_ le 20 then do;
    output work.orig;
    age=99;
    output work.changed;
  end;
  else if _n_ le 30 then do;
    year=_n_;
    output work.appended;
  end;
  else stop;
run;

%mp_storediffs(sashelp.electric,work.orig,CUSTOMER YEAR
  ,delds=work.deleted
  ,modds=work.changed
  ,appds=work.appended
  ,outds=work.final
  ,mdebug=1
)

%mp_assertscope(SNAPSHOT)

/**
  * Deletions test - where record does not exist
  */
%mp_stackdiffs(work.orig
  ,work.final
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds1
  ,outmod=work.mod1
  ,outadd=work.add1
  ,outdel=work.del1
)
%mp_assertdsobs(work.errds1,
  desc=Delete1 - no errors,
  test=EQUALS 0
)
%mp_assertdsobs(work.del1,
  desc=Delete1 - records populated,
  test=EQUALS 10
)
/**
  * Deletions test - where record DOES exist
  */
data work.orig2;
  set sashelp.electric;
  if _n_ le 10;
run;
%mp_stackdiffs(work.orig2
  ,work.final
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds2
  ,outmod=work.mod2
  ,outadd=work.add2
  ,outdel=work.del2
)
%mp_assertdsobs(work.errds2,
  desc=Delete1 - has errors,
  test=EQUALS 10
)
%mp_assertdsobs(work.del1,
  desc=Delete1 - records not populated,
  test=EQUALS 0
)


%mp_assertscope(COMPARE,Desc=MacVar Scope Check)