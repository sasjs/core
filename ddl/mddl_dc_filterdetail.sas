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
      processed_dttm num not null format=E8601DT26.6,
    constraint pk_mpe_filteranytable
      primary key(filter_hash,filter_line)
  );

%mend mddl_dc_filterdetail;