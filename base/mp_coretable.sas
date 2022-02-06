/**
  @file
  @brief Create the permanent Core tables
  @details Several macros in the [core](https://github.com/sasjs/core) library
    make use of permanent tables.  To avoid duplication in definitions, this
    macro provides a central location for managing the corresponding DDL.

  Note - this macro is likely to be deprecated in future in favour of a
  dedicated "datamodel" folder (prefix mddl)

  Any corresponding data would go in a seperate repo, to avoid this one
  ballooning in size!

  Example usage:

      %mp_coretable(LOCKTABLE,libds=work.locktable)

  @param [in] table_ref The type of table to create.  Example values:
    @li DIFFTABLE - Used to store changes to tables.  Used by mp_storediffs.sas
      and mp_stackdiffs.sas
    @li FILTER_DETAIL - For storing detailed filter values.  Used by
      mp_filterstore.sas.
    @li FILTER_SUMMARY - For storing summary filter values.  Used by
      mp_filterstore.sas.
    @li LOCKANYTABLE - For "locking" tables prior to multipass loads. Used by
      mp_lockanytable.sas
    @li MAXKEYTABLE - For storing the maximum retained key information.  Used
      by mp_retainedkey.sas
  @param [in] libds= (0) The library.dataset reference used to create the table.
    If not provided, then the DDL is simply printed to the log.

  <h4> Related Macros </h4>
  @li mp_filterstore.sas
  @li mp_lockanytable.sas
  @li mp_retainedkey.sas
  @li mp_storediffs.sas
  @li mp_stackdiffs.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_coretable(table_ref,libds=0
)/*/STORE SOURCE*/;
%local outds ;
%let outds=%sysfunc(ifc(&libds=0,_data_,&libds));
proc sql;
%if &table_ref=DIFFTABLE %then %do;
  create table &outds(
      load_ref char(36) label='unique load reference',
      processed_dttm num format=E8601DT26.6 label='Processed at timestamp',
      libref char(8) label='Library Reference (8 chars)',
      dsn char(32) label='Dataset Name (32 chars)',
      key_hash char(32) label=
        'MD5 Hash of primary key values (pipe seperated)',
      move_type char(1) label='Either (A)ppended, (D)eleted or (M)odified',
      is_pk num label='Is Primary Key Field? (1/0)',
      is_diff num label=
        'Did value change? (1/0/-1).  Always -1 for appends and deletes.',
      tgtvar_type char(1) label='Either (C)haracter or (N)umeric',
      tgtvar_nm char(32) label='Target variable name (32 chars)',
      oldval_num num format=best32. label='Old (numeric) value',
      newval_num num format=best32. label='New (numeric) value',
      oldval_char char(32765) label='Old (character) value',
      newval_char char(32765) label='New (character) value',
    constraint pk_mpe_audit
      primary key(load_ref,libref,dsn,key_hash,tgtvar_nm)
  );
%end;
%else %if &table_ref=LOCKTABLE %then %do;
  create table &outds(
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
%else %if &table_ref=FILTER_SUMMARY %then %do;
  create table &outds(
      filter_rk num not null,
      filter_hash char(32) not null,
      filter_table char(41) not null,
      processed_dttm num not null format=E8601DT26.6,
    constraint pk_mpe_filteranytable
      primary key(filter_rk));
%end;
%else %if &table_ref=FILTER_DETAIL %then %do;
  create table &outds(
      filter_hash char(32) not null,
      filter_line num not null,
      group_logic char(3) not null,
      subgroup_logic char(3) not null,
      subgroup_id num not null,
      variable_nm varchar(32) not null,
      operator_nm varchar(12) not null,
      raw_value varchar(4000) not null,
      processed_dttm num not null format=E8601DT26.6,
    constraint pk_mpe_filteranytable
      primary key(filter_hash,filter_line));
%end;
%else %if &table_ref=MAXKEYTABLE %then %do;
  create table &outds(
      keytable varchar(41) label='Base table in libref.dataset format',
      keycolumn char(32) format=$32.
        label='The Retained key field containing the key values.',
      max_key num label=
        'Integer representing current max RK or SK value in the KEYTABLE',
      processed_dttm num format=E8601DT26.6
        label='Datetime this value was last updated',
    constraint pk_mpe_maxkeyvalues
        primary key(keytable));
%end;


%if &libds=0 %then %do;
  describe table &syslast;
  drop table &syslast;
%end;
%mend mp_coretable;