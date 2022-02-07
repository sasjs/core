/**
  @file
  @brief Difftable DDL
  @details Used to store changes to tables.  Used by mp_storediffs.sas
      and mp_stackdiffs.sas

**/


%macro mddl_dc_difftable(libds=WORK.DIFFTABLE);

  proc sql;
  create table &libds(
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

%mend mddl_dc_difftable;