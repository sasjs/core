/**
  @file
  @brief Filtersummary DDL
  @details For storing summary filter values.  Used by
      mp_filterstore.sas.

**/


%macro mddl_dc_filtersummary(libds=WORK.FILTER_SUMMARY);

%local nn lib;
%if "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5" %then %do;
  %let nn=not null;
%end;
%else %let nn=;

  proc sql;
  create table &libds(
      filter_rk num &nn,
      filter_hash char(32) &nn,
      filter_table char(41) &nn,
      processed_dttm num &nn format=E8601DT26.6
  );

  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create filter_rk /nomiss unique;
  quit;

%mend mddl_dc_filtersummary;