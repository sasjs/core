/**
  @file
  @brief Testing mp_storediffs macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas
  @li mp_stackdiffs.sas
  @li mp_storediffs.sas

**/

/* first, make some data */

data work.orig work.deleted work.changed work.appended;
  set sashelp.electric;
  if _n_ le 10 then do;
    output work.orig work.deleted;
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

/* now, stack it back */