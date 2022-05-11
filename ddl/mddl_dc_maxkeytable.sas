/**
  @file
  @brief Maxkeytable DDL
  @details For storing the maximum retained key information.  Used
      by mp_retainedkey.sas

**/


%macro mddl_dc_maxkeytable(libds=WORK.MAXKEYTABLE);

  proc sql;
  create table &libds(
      keytable varchar(41) label='Base table in libref.dataset format',
      keycolumn char(32) format=$32.
        label='The Retained key field containing the key values.',
      max_key num label=
        'Integer representing current max RK or SK value in the KEYTABLE',
      processed_dttm num format=E8601DT26.6
        label='Datetime this value was last updated'
  );

  %local lib;
  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create keytable /nomiss unique;
  quit;

%mend mddl_dc_maxkeytable;