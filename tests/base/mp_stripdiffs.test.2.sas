/**
  @file
  @brief Testing mp_stripdiffs.sas macro with special missing values

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_storediffs.sas
  @li mp_stripdiffs.sas

**/

/* Both the key and the changed cells hold special missings - reverting them
  means writing ._ / .A / .Z back into a PROC SQL statement */
libname libby (work);
data libby.spm;
  pknum=._; grp='a'; score=._; output;
  pknum=.A; grp='b'; score=7;  output;
  pknum=.Z; grp='c'; score=.B; output;
  pknum=1;  grp='d'; score=.;  output;
run;

/* the original snapshot, and the change sets to be applied to the base */
data work.orig work.deleted work.changed;
  set libby.spm;
  output work.orig;
  if pknum=._ then output work.deleted;
  else if pknum=.A then do;
    score=42;
    output work.changed;
  end;
  else if pknum=.Z then do;
    score=99;
    output work.changed;
  end;
run;
data work.appended;
  pknum=.C; grp='e'; score=1;  output;
  pknum=8;  grp='f'; score=.Q; output;
run;

/* first, store the diffs */
%mp_storediffs(libby.spm,work.orig,PKNUM GRP
  ,delds=work.deleted
  ,modds=work.changed
  ,appds=work.appended
  ,outds=work.audit
  ,loadref=SPM1
  ,mdebug=0
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking diffs were stored for special missing values,
  outds=work.test_results
)

/* now apply those changes to the base table */
proc sql;
delete from libby.spm where pknum=._;
delete from libby.spm where pknum=.A;
delete from libby.spm where pknum=.Z;
quit;
proc append base=libby.spm data=work.changed;
run;
proc append base=libby.spm data=work.appended;
run;

/* prepare the revert dataset */
%mp_assertscope(SNAPSHOT)
%mp_stripdiffs(libby.spm
  ,SPM1
  ,work.audit
  ,outds=work.sd_stage
  ,mdebug=1
)
%mp_assertscope(COMPARE)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking no failure when reverting special missing values,
  outds=work.test_results
)

/* the reverted stage should be the original four rows, with the two appended
  rows marked for deletion */
data work.sd_expected;
  pknum=._; grp='a'; score=._; delflag='No';  output;
  pknum=.A; grp='b'; score=7;  delflag='No';  output;
  pknum=.Z; grp='c'; score=.B; delflag='No';  output;
  pknum=1;  grp='d'; score=.;  delflag='No';  output;
  pknum=.C; grp='e'; score=1;  delflag='Yes'; output;
  pknum=8;  grp='f'; score=.Q; delflag='Yes'; output;
run;
data work.sd_actual;
  set work.sd_stage(rename=(_____DELETE__THIS__RECORD_____=delflag));
  length delflag $3;
run;

proc compare base=work.sd_expected compare=work.sd_actual;
run;
data _null_;
  /* data-relevant bits only: 64 missing obs, 128 extra obs, 4096 unequal
    values, 32768 different number of observations */
  call symputx('cmpfail',band(&sysinfo,64+128+4096+32768),'l');
run;
%mp_assert(
  iftrue=(&cmpfail=0),
  desc=Checking restored values match the original for special missings,
  outds=work.test_results
)
