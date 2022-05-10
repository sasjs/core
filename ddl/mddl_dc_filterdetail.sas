/**
  @file
  @brief Filtertable DDL
  @details For storing detailed filter values.  Used by
      mp_filterstore.sas.

**/


%macro mddl_dc_filterdetail(libds=WORK.FILTER_DETAIL);

%local nn lib;
%if "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5" %then %do;
  %let nn=not null;
%end;
%else %let nn=;

  proc sql;
  create table &libds(
      filter_hash char(32) &nn,
      filter_line num &nn,
      group_logic char(3) &nn,
      subgroup_logic char(3) &nn,
      subgroup_id num &nn,
      variable_nm varchar(32) &nn,
      operator_nm varchar(12) &nn,
      raw_value varchar(4000) &nn,
      processed_dttm num &nn format=E8601DT26.6
  );

  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create pk_mpe_filterdetail=(filter_hash filter_line)/nomiss unique;
  quit;

%mend mddl_dc_filterdetail;