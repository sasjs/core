/**
  @file
  @brief Extract the primary key fields from a table or library
  @details Examines the constraints to identify primary key fields - indicated
  by an explicit PK constraint, or a unique index that is also NOT NULL.

  Can be executed at both table and library level.  Supports both BASE engine
  libraries and SQL Server.

  Usage:

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
      %mp_getpk(work,ds=example)

  Returns:


  @param [in] lib The libref to examine
  @param [in] ds= (0) Select the dataset to examine, else use 0 for all tables
  @param [in] mdebug= (0) Set to 1 to preserve temp tables, print var values etc
  @param [out] outds= (work.mp_getpk) The name of the output table to create.

  <h4> SAS Macros </h4>
  @li mf_getengine.sas
  @li mf_getschema.sas
  @li mp_dropmembers.sas
  @li mp_getconstraints.sas

  <h4> Related Macros </h4>
  @li mp_getpk.test.sas

  @version 9.3
  @author Macro People Ltd
**/

%macro mp_getpk(
  lib,
  ds=0,
  outds=work.mp_getpk,
  mdebug=0
)/*/STORE SOURCE*/;


%local engine schema ds1 ds2 ds3 dsn tabs1 tabs2 sum pk4sure pkdefault finalpks;

%let lib=%upcase(&lib);
%let ds=%upcase(&ds);
%let engine=%mf_getengine(&lib);
%let schema=%mf_getschema(&lib);

%let ds1=%mf_getuniquename(prefix=getpk_ds1);
%let ds2=%mf_getuniquename(prefix=getpk_ds2);
%let ds3=%mf_getuniquename(prefix=getpk_ds3);
%let tabs1=%mf_getuniquename(prefix=getpk_tabs1);
%let tabs2=%mf_getuniquename(prefix=getpk_tabs2);
%let sum=%mf_getuniquename(prefix=getpk_sum);
%let pk4sure=%mf_getuniquename(prefix=getpk_pk4sure);
%let pkdefault=%mf_getuniquename(prefix=getpk_pkdefault);
%let finalpks=%mf_getuniquename(prefix=getpk_finalpks);

%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

proc sql;
create table &ds1 as
  select  libname as libref
    ,upcase(memname) as dsn
    ,memtype
    ,upcase(name) as name
    ,type
    ,length
    ,varnum
    ,label
    ,format
    ,idxusage
    ,notnull
  from dictionary.columns
  where upcase(libname)="&lib"
%if &ds ne 0 %then %do;
    and upcase(memname)="&ds"
%end;
  ;


%if &engine=SQLSVR %then %do;
  proc sql;
  connect using &lib;
  create table work.&ds2 as
  select * from connection to &lib(
  select
      s.name as SchemaName,
      t.name as memname,
      tc.name as name,
      ic.key_ordinal as KeyOrderNr
  from
      sys.schemas s
      inner join sys.tables t   on s.schema_id=t.schema_id
      inner join sys.indexes i  on t.object_id=i.object_id
      inner join sys.index_columns ic on i.object_id=ic.object_id
                                    and i.index_id=ic.index_id
      inner join sys.columns tc on ic.object_id=tc.object_id
                              and ic.column_id=tc.column_id
  where i.is_primary_key=1
    and s.name=%str(%')&schema%str(%')
  order by t.name, ic.key_ordinal ;
  );disconnect from &lib;
  create table &ds3 as
    select a.*
      ,case when b.name is not null then 1 else 0 end as pk_ind
    from work.&ds1 a
    left join work.&ds2 b
    on a.dsn=b.memname
      and upcase(a.name)=upcase(b.name)
    order by libref,dsn;
%end;
%else %do;

  %if &ds = 0 %then %let dsn=;

  /* get all constraints, in constraint order*/
  %mp_getconstraints(lib=&lib,ds=&dsn,outds=work.&ds2)

  /* extract cols that are clearly primary keys */
  proc sql;
  create table &pk4sure as
    select libref
      ,table_name
      ,constraint_name
      ,constraint_order
      ,column_name as name
    from work.&ds2
    where constraint_type='PRIMARY'
    order by 1,2,3,4;

  /* extract unique constraints where every col is also NOT NULL */
  proc sql;
  create table &sum as
    select a.libref
      ,a.table_name
      ,a.constraint_name
      ,count(a.column_name) as unq_cnt
      ,count(b.column_name) as nul_cnt
    from work.&ds2(where=(constraint_type ='UNIQUE')) a
    left join work.&ds2(where=(constraint_type ='NOT NULL')) b
    on a.libref=b.libref
      and a.table_name=b.table_name
      and a.column_name=b.column_name
    group by 1,2,3
    having unq_cnt=nul_cnt;

  /* extract cols from the relevant unique constraints */
  create table &pkdefault as
    select a.libref
      ,a.table_name
      ,a.constraint_name
      ,b.constraint_order
      ,b.column_name as name
    from &sum a
    left join &ds2(where=(constraint_type ='UNIQUE')) b
    on a.libref=b.libref
      and a.table_name=b.table_name
      and a.constraint_name=b.constraint_name
    order by 1,2,3,4;

  /* create one table */
  data &finalpks;
    set &pkdefault &pk4sure ;
    pk_ind=1;
    /* if there are multiple unique constraints, take the first */
    by libref table_name constraint_name;
    retain keepme;
    if first.table_name then keepme=1;
    if first.constraint_name and not first.table_name then keepme=0;
    if keepme=1;
  run;

  /* join back to starting table */
  proc sql;
  create table &ds3 as
    select a.*
      ,b.constraint_order
      ,case when b.pk_ind=1 then 1 else 0 end as pk_ind
    from work.&ds1 a
    left join work.&finalpks b
    on a.libref=b.libref
      and a.dsn=b.table_name
      and upcase(a.name)=upcase(b.name)
    order by libref,dsn,constraint_order;
%end;


/* prepare tables */
proc sql;
create table work.&tabs1 as select
  libname as libref
  ,upcase(memname) as dsn
  ,memtype
  ,dbms_memtype
  ,typemem
  ,memlabel
  ,nvar
  ,compress
from dictionary.tables
  where upcase(libname)="&lib"
%if &ds ne 0 %then %do;
    and upcase(memname)="&ds"
%end;
  ;
data &tabs2;
  set &ds3;
  length pk_fields $512;
  retain pk_fields;
  by libref dsn constraint_order;
  if first.dsn then pk_fields='';
  if pk_ind=1 then pk_fields=catx(' ',pk_fields,name);
  if last.dsn then output;
run;

proc sql;
create table &outds as
  select a.libref
    ,a.dsn
    ,a.memtype
    ,a.dbms_memtype
    ,a.typemem
    ,a.memlabel
    ,a.nvar
    ,a.compress
    ,b.pk_fields
  from work.&tabs1 a
  left join work.&tabs2 b
  on a.libref=b.libref
    and a.dsn=b.dsn;

/* tidy up */
%mp_dropmembers(
  &ds1 &ds2 &ds3 &dsn &tabs1 &tabs2 &sum &pk4sure &pkdefault &finalpks,
  iftrue=(&mdebug=0)
)

%mend mp_getpk;