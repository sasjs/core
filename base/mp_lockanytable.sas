/**
  @file
  @brief Mechanism for locking tables to prevent parallel modifications
  @details Uses a control table to enable ANY table to be locked for updates.
  Only useful if every update uses the macro!   Used heavily within
  [Data Controller for SAS](https://datacontroller.io).

  The underlying table is structured as per the MAKETABLE action.

  @param [in] action The action to be performed.  Valid values:
    @li LOCK - Sets the lock flag, also confirms if a SAS lock is available
    @li UNLOCK - Unlocks the table
    @li MAKETABLE - creates the control table (ctl_ds)
  @param [in] lib= (WORK) The libref of the table to lock.  Should already be
    assigned.
  @param [in] ds= The dataset to lock
  @param [in] ref= A meaningful reference to enable the lock to be traced. Max
    length is 200 characters.
  @param [out] ctl_ds= (0) The control table which controls the actual locking.
    Should already be assigned and available.
  @param [in] loops= (25) Number of times to check for a lock.
  @param [in] loop_secs= (1) Seconds to wait between each lock attempt

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_lockfilecheck.sas
  @li mf_getuser.sas

  @version 9.2

**/

%macro mp_lockanytable(
  action
  ,lib= WORK
  ,ds=0
  ,ref=
  ,ctl_ds=0
  ,loops=25
  ,loop_secs=1
  );
data _null_;
  if _n_=1 then putlog "&sysmacroname entry vars:";
  set sashelp.vmacro;
  where scope="&sysmacroname";
  put name '=' value;
run;

%mp_abort(iftrue= (&ds=0 and &action ne MAKETABLE)
  ,mac=&sysmacroname
  ,msg=%str(dataset was not provided)
)
%mp_abort(iftrue= (&ctl_ds=0)
  ,mac=&sysmacroname
  ,msg=%str(Control dataset was not provided)
)

/* set up lib & mac vars */
%let lib=%upcase(&lib);
%let ds=%upcase(&ds);
%let action=%upcase(&action);
%local user x trans msg abortme;
%let user=%mf_getuser();
%let abortme=0;

%mp_abort(iftrue= (&action ne LOCK & &action ne UNLOCK & &action ne MAKETABLE)
  ,mac=&sysmacroname
  ,msg=%str(Invalid action (&action) provided)
)

/* if an err condition exists, exit before we even begin */
%mp_abort(iftrue= (&syscc>0 and &action=LOCK)
  ,mac=&sysmacroname
  ,msg=%str(aborting due to syscc=&syscc on LOCK entry)
)

/* do not bother locking work tables (else may affect all WORK libraries) */
%if (%upcase(&lib)=WORK or %str(&lib)=%str()) & &action ne MAKETABLE %then %do;
  %put NOTE: WORK libraries will not be registered in the locking system.;
  %return;
%end;

/* do not proceed if no observations can be processed */
%mp_abort(iftrue= (%sysfunc(getoption(OBS))=0)
  ,mac=&sysmacroname
  ,msg=%str(options obs = 0. syserrortext=&syserrortext)
)

%if &ACTION=LOCK %then %do;

  /* abort if a SAS lock is already in place, or cannot be applied */
  %mp_lockfilecheck(&lib..&ds)

  /* next, check there is a record for this table */
  %local record_exists_check;
  proc sql noprint;
  select count(*) into: record_exists_check from &ctl_ds
    where LOCK_LIB ="&lib" and LOCK_DS="&ds";
  quit;
  %if &syscc>0 %then %put syscc=&syscc sqlrc=&sqlrc;
  %if &record_exists_check=0 %then %do;
    data _null_;
      putlog "&sysmacroname: adding record to lock table..";
    run;

    data ;
      if 0 then set &ctl_ds;
      LOCK_LIB ="&lib";
      LOCK_DS="&ds";
      LOCK_STATUS_CD='LOCKED';
      LOCK_START_DTTM="%sysfunc(datetime(),E8601DT26.6)"dt;
      LOCK_USER_NM="&user";
      LOCK_PID="&sysjobid";
      LOCK_REF="&ref";
      output;stop;
    run;
    %let trans=&syslast;
    proc append base=&ctl_ds data=&trans;
    run;
  %end;
  /* if record does exist, perform lock attempts */
  %else %do x=1 %to &loops;
    data _null_;
      putlog "&sysmacroname: attempting lock (iteration &x) "@;
      putlog "at %sysfunc(datetime(),datetime19.) ..";
    run;

    proc sql;
    update &ctl_ds
      set LOCK_STATUS_CD='LOCKED'
        , LOCK_START_DTTM="%sysfunc(datetime(),E8601DT26.6)"dt
        , LOCK_USER_NM="&user"
        , LOCK_PID="&sysjobid"
        , LOCK_REF="&ref"
      where LOCK_LIB ="&lib" and LOCK_DS="&ds";
    quit;
    /**
      * NOTE - occasionally SQL server will return an err code (deadlocked
      * transaction).  If so, ignore it, keep calm, and carry on..
      */
    %if &syscc>0 %then %do;
      data _null_;
        putlog 'NOTE-' / 'NOTE-';
        putlog "NOTE- &sysmacroname: Update failed. "@;
        putlog "Resetting err conditions and re-attempting.";
        putlog "NOTE- syscc=&syscc syserr=&syserr sqlrc=&sqlrc";
        putlog 'NOTE-' / 'NOTE-';
      run;
      %let syscc=0;
      %let sqlrc=0;
    %end;

    /* now check if the record was successfully updated */
    %local success_check;
    proc sql noprint;
    select count(*) into: success_check from &ctl_ds
      where LOCK_LIB ="&lib" and LOCK_DS="&ds"
        and LOCK_PID="&sysjobid" and LOCK_STATUS_CD='LOCKED';
    quit;
    %if &success_check=0 %then %do;
      %if &x < &loops %then %do;
        /* pause before next check */
        data _null_;
          putlog 'NOTE-' / 'NOTE-';
          putlog "NOTE- &sysmacroname: table locked, waiting "@;
          putlog "%sysfunc(sleep(&loop_inc)) seconds.. ";
          putlog "NOTE- (iteration &x of &loops)";
          putlog 'NOTE-' / 'NOTE-';
        run;
      %end;
      %else %do;
        %let msg=Unable to lock &lib..&ds via &ctl_ds after &loops attempts.\n
            Please ask your administrator to investigate!;
        %let abortme=1;
      %end;
    %end;
    %else %do;
      data _null_;
        putlog 'NOTE-' / 'NOTE-';
        putlog "NOTE- &sysmacroname: Table &lib..&ds locked at "@
        putlog " %sysfunc(datetime(),datetime19.) (iteration &x)"@;
        putlog 'NOTE-' / 'NOTE-';
      run;
      %if &syscc>0 %then %do;
        %put setting syscc(&syscc) back to 0;
        %let syscc=0;
      %end;
      %let x=&loops;  /* no more iterations needed */
    %end;
  %end;
%end;
%else %if &ACTION=UNLOCK %then %do;
  %local status;
  proc sql noprint;
  select LOCK_STATUS_CD into: status from &ctl_ds
    where LOCK_LIB ="&lib" and LOCK_DS="&ds";
  quit;
  %if &syscc>0 %then %put syscc=&syscc sqlrc=&sqlrc;
  %if &status=LOCKED %then %do;
    data _null_;
      putlog "&sysmacroname: unlocking &lib..&ds:";
    run;
    proc sql;
    update &ctl_ds
      set LOCK_STATUS_CD='UNLOCKED'
        , LOCK_END_DTTM="%sysfunc(datetime(),E8601DT26.6)"dt
        , LOCK_USER_NM="&user"
        , LOCK_PID="&sysjobid"
        , LOCK_REF="&ref"
      where LOCK_LIB ="&lib" and LOCK_DS="&ds";
    quit;
  %end;
  %else %if &status=UNLOCKED %then %do;
    %put %str(WAR)NING: &lib..&ds is already unlocked!;
  %end;
  %else %do;
    %put NOTE: Unrecognised STATUS_CD (&status) in &ctl_ds;
    %let abortme=1;
  %end;
%end;
%else %if &action=MAKETABLE %then %do;
  proc sql;
  create table &ctl_ds(
      lock_lib char(8),
      lock_ds char(32),
      lock_status_cd char(10) not null,
      lock_user_nm char(100) not null ,
      lock_ref char(200),
      lock_pid char(10),
      lock_start_dttm num format=E8601DT26.6,
      lock_end_dttm num format=E8601DT26.6,
    constraint pk_mp_lockanytable primary key(lock_lib,lock_ds));
%end;
%else %do;
  %let msg=lock_anytable given unsupported action (&action);
  %let abortme=1;
%end;

/* catch errors - mp_abort must be called outside of a logic block */
%mp_abort(iftrue=(&abortme=1),
  msg=%superq(msg),
  mac=&sysmacroname
)

%exit_macro:
data _null_;
  put "&sysmacroname: Exit vars: action=&action lib=&lib ds=&ds";
  put " syscc=&syscc sqlrc=&sqlrc syserr=&syserr";
run;
%mend mp_lockanytable;


