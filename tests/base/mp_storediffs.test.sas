/**
  @file
  @brief Testing mp_storediffs macro

  <h4> SAS Macros </h4>
  @li mp_storediffs.sas
  @li mp_assert.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas

**/

/* make some data */

data work.orig work.deleted work.changed work.appended;
  set sashelp.class;
  if _n_=1 then do;
    output work.orig work.deleted;
  end;
  else if _n_=2 then do;
    output work.orig;
    age=99;
    output work.changed;
  end;
  else do;
    name='Newbie';
    output work.appended;
    stop;
  end;
run;

%mp_storediffs(sashelp.class,work.orig,NAME
  ,delds=work.deleted
  ,modds=work.changed
  ,appds=work.appended
  ,outds=work.final
  ,mdebug=1
)

%mp_assert(
  iftrue=(
    %str(&syscc)=%str(0)
  ),
  desc=ensure no errors,
  outds=work.test_results
)

%mp_assertdsobs(work.final,
  desc=Has 15 records,
  test=EQUALS 15,
  outds=work.test_results
)

data work.check;
  length val $10;
  do val='C','N';
    output;
  end;
run;
%mp_assertcolvals(work.final.tgtvar_type,
  checkvals=work.check.val,
  desc=All values have a match,
  test=ALLVALS
)

/* Test for when there are no actual changes */
data work.orig work.deleted work.changed work.appended;
  set sashelp.class;
  output work.orig;
run;
%mp_storediffs(sashelp.class,work.orig,NAME
  ,delds=work.deleted
  ,modds=work.changed
  ,appds=work.appended
  ,outds=work.final2
  ,mdebug=1
)
%mp_assertdsobs(work.final2,
  desc=No changes produces 0 records,
  test=EQUALS 0,
  outds=work.test_results
)

/* Test for deletes only */
data work.orig work.deleted work.changed work.appended;
  set sashelp.class;
  output work.orig;
  if _n_>5 then output work.deleted;
run;

%mp_storediffs(sashelp.class,work.orig,NAME
  ,delds=work.deleted
  ,modds=work.changed
  ,appds=work.appended
  ,outds=work.final3
  ,mdebug=1
)
%mp_assertdsobs(work.final3,
  desc=Delete has 70 records,
  test=EQUALS 70,
  outds=work.test_results
)