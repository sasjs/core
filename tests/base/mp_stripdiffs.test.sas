/**
  @file
  @brief Testing mp_stripdiffs.sas macro
  @details

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_ds2md.sas
  @li mp_stripdiffs.sas

**/

/* make an adjustable base dataset */
/* use a composite key also (name weight) */
libname libby (work);
data libby.class;
  set sashelp.class;
run;

/* first, store some diffs */
data work.orig work.deleted work.changed work.appended;
  set libby.class;
  if _n_=1 then do;
    call symputx('delname',name);
    output work.orig work.deleted;
  end;
  else if _n_=2 then do;
    output work.orig;
    call symputx('modname',name);
    call symputx('modval',age);
    age=99;
    output work.changed;
  end;
  else do;
    name='Newbie';
    output work.appended;
    stop;
  end;
run;
%mp_storediffs(libby.class,work.orig,NAME WEIGHT
  ,delds=work.deleted
  ,modds=work.changed
  ,appds=work.appended
  ,outds=work.audit
  ,loadref=UPLOAD1
  ,mdebug=0
)
%mp_ds2md(work.audit)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking preparation case,
  outds=work.test_results
)

/* apply the changes */
proc sql;
delete from libby.class where name in ("&delname","&modname");
proc append base=libby.class data=work.appended;
proc append base=libby.class data=work.changed;
run;

/* now, prepare the revert dataset */
%mp_assertscope(SNAPSHOT)
%mp_stripdiffs(libby.class
  ,UPLOAD1
  ,work.audit
  ,outds=work.mp_stripdiffs
  ,mdebug=1
)
%mp_ds2md(work.mp_stripdiffs)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking error condition,
  outds=work.test_results
)

%let delpass=0;
%let modpass=0;
%let addpass=0;
data _null_;
  set work.mp_stripdiffs;
  if upcase(_____DELETE__THIS__RECORD_____)='NO' and name="&delname"
  then call symputx('delpass',1);
  if name="&modname" and age=&modval then call symputx('modpass',1);
  if upcase(_____DELETE__THIS__RECORD_____)='YES' and name="Newbie"
  then call symputx('addpass',1);
run;

%mp_assert(
  iftrue=(&delpass=1),
  desc=Ensuring deleted record is back in the dataset,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&modpass=1),
  desc=Ensuring modified record now has old value,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&addpass=1),
  desc=Ensuring added record is now marked for deletion,
  outds=work.test_results
)