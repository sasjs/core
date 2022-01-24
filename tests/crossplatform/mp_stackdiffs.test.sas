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
    coal=-1;
    coaltip='modified';
    output work.changed;
  end;
  else if _n_ le 30 then do;
    year=_n_;
    output work.appended;
  end;
  else stop;
run;

%mp_storediffs(sashelp.electric
  ,work.orig
  ,CUSTOMER YEAR
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
data work.final1;
  set work.final;
  where move_type='D';
run;
%mp_stackdiffs(work.orig
  ,work.final1
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds1
  ,outmod=work.mod1
  ,outadd=work.add1
  ,outdel=work.del1
)
%mp_assertdsobs(work.errds1,
  desc=Delete1 - no errs,
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
data work.final2;
  set work.final;
  where move_type='D';
run;
%mp_stackdiffs(work.orig2
  ,work.final2
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds2
  ,outmod=work.mod2
  ,outadd=work.add2
  ,outdel=work.del2
)
%mp_assertdsobs(work.errds2,
  desc=Delete1 - has errs,
  test=EQUALS 10
)
%mp_assertdsobs(work.del1,
  desc=Delete1 - records not populated,
  test=EQUALS 0
)

/**
  * Additions test - where record does not exist
  */
data work.orig3;
  set work.orig;
  stop;
run;
data work.final3;
  set work.final;
  where move_type='A';
run;
%mp_stackdiffs(work.orig3
  ,work.final3
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds3
  ,outmod=work.mod3
  ,outadd=work.add3
  ,outdel=work.del3
)
%mp_assertdsobs(work.errds3,
  desc=Add3 - no errs,
  test=EQUALS 0
)
%mp_assertdsobs(work.add3,
  desc=Add3 - records populated,
  test=EQUALS 10
)

/**
  * Additions test - where record does exist
  */
data work.orig4;
  set work.orig;
  if _n_>35 then stop;
run;
data work.final4;
  set work.final;
  where move_type='A';
run;
%mp_stackdiffs(work.orig4
  ,work.final4
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds4
  ,outmod=work.mod4
  ,outadd=work.add4
  ,outdel=work.del4
)
%mp_assertdsobs(work.errds4,
  desc=Add4 - 5 errs,
  test=EQUALS 5
)
%mp_assertdsobs(work.add4,
  desc=Add4 - records populated,
  test=EQUALS 5
)

/**
  * Additions test - where base table has missing vars
  */
data work.orig5;
  set work.orig;
  drop Coal;
run;
data work.final5;
  set work.final;
  where move_type='A';
run;
%mp_stackdiffs(work.orig5
  ,work.final5
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds5
  ,outmod=work.mod5
  ,outadd=work.add5
  ,outdel=work.del5
)
%mp_assertdsobs(work.errds5,
  desc=Add5 - 10 errs,
  test=EQUALS 10
)
%mp_assertdsobs(work.add5,
  desc=Add5 - 0 records populated due to structure change,
  test=EQUALS 0
)

/**
  * Additions test - where append table has missing vars
  */
data work.final6;
  set work.final;
  where tgtvar_nm ne 'COAL' and move_type='A';
run;
%mp_stackdiffs(work.orig
  ,work.final6
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds6
  ,outmod=work.mod6
  ,outadd=work.add6
  ,outdel=work.del6
)
%mp_assertdsobs(work.errds6,
  desc=Add6 - 0 errs,
  test=EQUALS 0
)
%mp_assertdsobs(work.add6,
  desc=Add6 - 10 records populated (structure change irrelevant),
  test=EQUALS 10
)

/**
  * Modifications test - where base table has missing vars
  */
data work.orig7;
  set work.orig;
  drop Coal;
run;
data work.final7;
  set work.final;
  where move_type='M';
run;
%mp_stackdiffs(work.orig7
  ,work.final7
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds7
  ,outmod=work.mod7
  ,outadd=work.add7
  ,outdel=work.del7
)
%mp_assertdsobs(work.errds7,
  desc=Mod7 - 10 errs,
  test=EQUALS 10
)
%mp_assertdsobs(work.Mod7,
  desc=Mod7 - 0 records populated (structure change relevant),
  test=EQUALS 0
)
%mp_assertdsobs(work.add7,
  desc=add7 - 0 records populated ,
  test=EQUALS 0
)
%mp_assertdsobs(work.del7,
  desc=del7 - 0 records populated ,
  test=EQUALS 0
)
/**
  * Modifications (big) test - where base table has missing rows
  * Also used as a full integration test (all move_types)
  * And a test if the actual values were applied
  */
data work.orig8;
  set work.orig;
  if _n_ le 16;
run;
%mp_stackdiffs(work.orig8
  ,work.final
  ,CUSTOMER YEAR
  ,mdebug=1
  ,errds=work.errds8
  ,outmod=work.mod8
  ,outadd=work.add8
  ,outdel=work.del8
)
%mp_assertdsobs(work.errds8,
  desc=Mod4 - 4 errs,
  test=EQUALS 4
)
%mp_assertdsobs(work.Mod8,
  desc=Mod8 - 6 records populated (missing rows relevant),
  test=EQUALS 6
)

/**
  * Modifications test - were diffs actually applied?
  */
data work.checkds;
  charchk='modified';
  numchk=-1;
  output;
run;
%mp_assertcolvals(work.mod8.coal,
  checkvals=work.checkds.numchk,
  desc=Modified numeric value matches,
  test=ALLVALS
)
%mp_assertcolvals(work.mod8.coaltip,
  checkvals=work.checkds.charchk,
  desc=Modified char value matches,
  test=ALLVALS
)


%mp_assertscope(COMPARE,Desc=MacVar Scope Check)