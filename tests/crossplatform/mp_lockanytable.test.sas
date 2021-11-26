/**
  @file
  @brief Testing mp_lockfilecheck macro

  <h4> SAS Macros </h4>
  @li mp_lockanytable.sas
  @li mp_assertcols.sas
  @li mp_assertcolvals.sas

**/

/* check create table */

%mp_lockanytable(MAKETABLE, ctl_ds=work.controller)

%mp_assertcols(work.controller,
  cols=lock_status_cd lock_lib lock_ds lock_user_nm lock_ref lock_pid
    lock_start_dttm lock_end_dttm,
  test=ALL,
  desc=check all control columns exist
)

/* check lock table */
options dlcreatedir;
libname tmp "%sysfunc(pathname(work))/tmp";
data tmp.sometable;
  x=1;
run;

%mp_lockanytable(LOCK,lib=tmp,ds=sometable,ref=This Ref, ctl_ds=work.controller)

data work.checkds1;
  checkval='SOMETABLE';
run;
%mp_assertcolvals(work.controller.lock_ds,
  checkvals=work.checkds1.checkval,
  desc=table is captured in lock,
  test=ANYVAL
)

data work.checkds2;
  checkval='LOCKED';
run;
%mp_assertcolvals(work.controller.lock_status_cd,
  checkvals=work.checkds2.checkval,
  desc=code is captured in lock,
  test=ANYVAL
)



/* check for unsuccessful unlock */
%mp_lockanytable(UNLOCK,lib=tmp,ds=sometable,ref=bye, ctl_ds=work.controller)

data work.checkds3;
  checkval='UNLOCKED';
run;
%mp_assertcolvals(work.controller.lock_status_cd,
  checkvals=work.checkds3.checkval,
  desc=Ref is captured in unlock,
  test=ANYVAL
)
