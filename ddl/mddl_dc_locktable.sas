/**
  @file
  @brief Locktable DDL
  @details For "locking" tables prior to multipass loads. Used by
      mp_lockanytable.sas

**/


%macro mddl_dc_locktable(libds=WORK.LOCKTABLE);

  proc sql;
  create table &libds(
      lock_lib char(8),
      lock_ds char(32),
      lock_status_cd char(10) not null,
      lock_user_nm char(100) not null ,
      lock_ref char(200),
      lock_pid char(10),
      lock_start_dttm num format=E8601DT26.6,
      lock_end_dttm num format=E8601DT26.6,
    constraint pk_mp_lockanytable primary key(lock_lib,lock_ds)
  );

%mend mddl_dc_locktable;