/**
  @file
  @brief DDL for the derived variables control table
  @details Creates the table read by mp_derivedvars.sas.  One row defines one
  derived variable for one target table.

  Usage:

      %mddl_derivedvars(libds=perm.derived_vars)

  <h4> Related Macros </h4>
  @li mp_derivedvars.sas

  @param [in] libds= (work.derived_vars) The table to create.  The libref must
    be assigned, and the table must not already exist.

  @version 5.6
  @author 4GL Apps Ltd
  @copyright 4GL Apps Ltd.  This code may only be used within Data Controller
    and may not be re-distributed or re-sold without the express permission of
    4GL Apps Ltd.

**/

%macro mddl_derivedvars(libds=work.derived_vars);

  %local lib;
  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc sql;
  create table &libds(
      libref char(8) label='Library Reference (8 chars)',
      dsn char(32) label='Dataset Name (32 chars)',
      var_nm char(32) label='Name of the derived variable',
      var_order num label='Evaluation order (integer, lowest first)',
      var_type char(1) label='Either (C)haracter or (N)umeric',
      var_len num label='Length of the derived variable',
      var_fmt char(32) label='SAS format, eg DATE9.',
      var_logic char(4000) label='SAS expression that produces the value',
      active num label='Is the variable active? (1/0)'
  );
  quit;

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create
      pk_derivedvars=(libref dsn var_nm)
      /nomiss unique;
  quit;

%mend mddl_derivedvars;
