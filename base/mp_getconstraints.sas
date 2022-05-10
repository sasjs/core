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

  @param [in] lib= (WORK) The target library
  @param [in] ds= The target dataset.  Leave blank (default) for all datasets.
  @param [in] mdebug= (0) Set to 1 to preserve temp tables, print var values etc
  @param [out] outds= (mp_getconstraints) the output dataset

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_dropmembers.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getconstraints(lib=WORK
  ,ds=
  ,outds=mp_getconstraints
  ,mdebug=0
)/*/STORE SOURCE*/;

%let lib=%upcase(&lib);
%let ds=%upcase(&ds);

/**
  * Cater for environments where sashelp.vcncolu is not available
  */
%if %sysfunc(exist(sashelp.vcncolu,view))=0 %then %do;
  proc sql;
  create table &outds(
      libref char(8)
    ,TABLE_NAME char(32)
    ,constraint_type char(8)     label='Constraint Type'
    ,constraint_name char(32)     label='Constraint Name'
    ,column_name char(32)     label='Column'
    ,constraint_order num
  );
  %return;
%end;

/**
  * Neither dictionary tables nor sashelp provides a constraint order column,
  * however they DO arrive in the correct order.  So, create the col.
  **/
%local vw;
%let vw=%mf_getuniquename(prefix=mp_getconstraints_vw_);
data &vw /view=&vw;
  set sashelp.vcncolu;
  where table_catalog="&lib";

  /* use retain approach to reset the constraint order with each constraint */
  length tmp $1000;
  retain tmp;
  drop tmp;
  if tmp ne catx('|',table_catalog,table_name,constraint_name) then do;
    constraint_order=1;
  end;
  else constraint_order+1;
  tmp=catx('|',table_catalog, table_name,constraint_name);
run;

/* must use SQL as proc datasets does not support length changes */
proc sql noprint;
create table &outds as
  select upcase(a.TABLE_CATALOG) as libref
    ,upcase(a.TABLE_NAME) as TABLE_NAME
    ,a.constraint_type
    ,a.constraint_name
    ,b.column_name
    ,b.constraint_order
  from dictionary.TABLE_CONSTRAINTS a
  left join &vw  b
  on upcase(a.TABLE_CATALOG)=upcase(b.TABLE_CATALOG)
    and upcase(a.TABLE_NAME)=upcase(b.TABLE_NAME)
    and a.constraint_name=b.constraint_name
/**
  * We cannot apply this clause to the underlying dictionary table.  See:
  * https://communities.sas.com/t5/SAS-Programming/Unexpected-Where-Clause-behaviour-in-dictionary-TABLE/m-p/771554#M244867
  */
  where calculated libref="&lib"
  %if "&ds" ne "" %then %do;
    and upcase(a.TABLE_NAME)="&ds"
    and upcase(b.TABLE_NAME)="&ds"
  %end;
  order by libref, table_name, constraint_name, constraint_order
  ;

/* tidy up */
%mp_dropmembers(
  &vw,
  iftrue=(&mdebug=0)
)

%mend mp_getconstraints;