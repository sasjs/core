/**
  @file mp_getconstraints.sas
  @brief Get constraint details at column level
  @details Useful for capturing constraints before they are dropped / reapplied
  during an update.

        proc sql;
        create table work.example(
          TX_FROM float format=datetime19.,
          DD_TYPE char(16),
          DD_SOURCE char(2048),
          DD_SHORTDESC char(256),
          constraint pk primary key(tx_from, dd_type,dd_source),
          constraint unq unique(tx_from, dd_type),
          constraint nnn not null(DD_SHORTDESC)
        );
      
      %mp_getconstraints(lib=work,ds=example,outds=work.constraints)

  @param lib= The target library (default=WORK)
  @param ds= The target dataset.  Leave blank (default) for all datasets.
  @param outds the output dataset

  <h4> Dependencies </h4>

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getconstraints(lib=WORK
  ,ds=
  ,outds=mp_getconstraints
)/*/STORE SOURCE*/;

%let lib=%upcase(&lib);
%let ds=%upcase(&ds);

/* must use SQL as proc datasets does not support length changes */
proc sql noprint;
create table &outds as
  select a.TABLE_CATALOG as libref
    ,a.TABLE_NAME
    ,a.constraint_type
    ,a.constraint_name
    ,b.column_name
  from dictionary.TABLE_CONSTRAINTS a
  left join dictionary.constraint_column_usage  b
  on a.TABLE_CATALOG=b.TABLE_CATALOG
    and a.TABLE_NAME=b.TABLE_NAME
    and a.constraint_name=b.constraint_name
  where a.TABLE_CATALOG="&lib"  
    and b.TABLE_CATALOG="&lib"  
  %if "&ds" ne "" %then %do;
    and a.TABLE_NAME="&ds"
    and b.TABLE_NAME="&ds"
  %end;
  ;

%mend;