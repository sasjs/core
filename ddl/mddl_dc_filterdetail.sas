/**
  @file
  @brief Filtertable DDL
  @details For storing detailed filter values.  Used by
      mp_filterstore.sas.

**/


%macro mddl_dc_filterdetail(libds=WORK.FILTER_DETAIL);

  proc sql;
  create table &libds(
      filter_hash char(32) not null,
      filter_line num not null,
      group_logic char(3) not null,
      subgroup_logic char(3) not null,
      subgroup_id num not null,
      variable_nm varchar(32) not null,
      operator_nm varchar(12) not null,
      raw_value varchar(4000) not null,
      processed_dttm num not null format=E8601DT26.6
  );

  %local lib;
  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create
      pk_mpe_filterdetail=(filter_hash filter_line)
      /nomiss unique;
  quit;

%mend mddl_dc_filterdetail;