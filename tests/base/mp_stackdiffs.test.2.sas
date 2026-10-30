/**
  @file
  @brief Testing mp_stackdiffs.sas macro with special missing values

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_stackdiffs.sas
  @li mp_storediffs.sas

**/

/* re-applying a change means writing the new value into a PROC SQL statement,
  so a special missing needs to survive as ._ / .A / .Z */
libname libby (work);
data libby.spm;
  pknum=.A; grp='a'; score=2;  output;
  pknum=.Z; grp='b'; score=.B; output;
  pknum=3;  grp='c'; score=.Q; output;
run;

data work.orig work.changed;
  set libby.spm;
  output work.orig;
  if pknum=.A then do;
    score=._;
    output work.changed;
  end;
  else if pknum=.Z then do;
    score=.D;
    output work.changed;
  end;
run;

/* store the diffs, then re-apply them */
%mp_storediffs(libby.spm,work.orig,PKNUM GRP
  ,modds=work.changed
  ,outds=work.audit
  ,loadref=SPM2
  ,mdebug=0
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking diffs were stored for special missing values,
  outds=work.test_results
)

data work.st_mods;
  set work.audit;
  where move_type='M';
run;

%mp_assertscope(SNAPSHOT)
%mp_stackdiffs(libby.spm
  ,work.st_mods
  ,PKNUM GRP
  ,mdebug=1
  ,errds=work.st_errds
  ,outmod=work.st_outmod
  ,outadd=work.st_outadd
  ,outdel=work.st_outdel
)
%mp_assertscope(COMPARE)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking no failure when stacking special missing values,
  outds=work.test_results
)

data work.st_expected;
  pknum=.A; grp='a'; score=._; output;
  pknum=.Z; grp='b'; score=.D; output;
run;

proc compare base=work.st_expected compare=work.st_outmod;
run;
data _null_;
  /* data-relevant bits only: 64 missing obs, 128 extra obs, 4096 unequal
    values, 32768 different number of observations */
  call symputx('cmpfail',band(&sysinfo,64+128+4096+32768),'l');
run;
%mp_assert(
  iftrue=(&cmpfail=0),
  desc=Checking stacked values match the new values for special missings,
  outds=work.test_results
)
