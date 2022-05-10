/**
  @file
  @brief Locktable DDL
  @details For "locking" tables prior to multipass loads. Used by
      mp_lockanytable.sas

**/


%macro mddl_dc_locktable(libds=WORK.LOCKTABLE);

%local nn lib;
%if "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5" %then %do;
  %let nn=not null;
%end;
%else %let nn=;

  proc sql;
  create table &libds(
      lock_lib char(8),
      lock_ds char(32),
      lock_status_cd char(10) &nn,
      lock_user_nm char(100) &nn ,
      lock_ref char(200),
      lock_pid char(10),
      lock_start_dttm num format=E8601DT26.6,
      lock_end_dttm num format=E8601DT26.6
  );

  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create
      pk_mp_lockanytable=(lock_lib lock_ds)
      /nomiss unique;
  quit;

%mend mddl_dc_locktable;