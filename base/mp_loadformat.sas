/**
  @file
  @brief Loads a format catalog from a staging dataset
  @details When loading staged data, it is common to receive only the records
  that have actually changed.  However, when loading a format catalog, if
  records are missing they are presumed to be no longer required.

  This macro will augment a staging dataset with other records from the same
  format, to prevent loss of data - UNLESS the input dataset contains a marker
  column, specifying that a particular row needs to be deleted (`delete_col=`).

  This macro can also be used to identify which records would be (or were)
  considered new, modified or deleted (`loadtarget=`) by creating the following
  tables:

  @li work.outds_add
  @li work.outds_del
  @li work.outds_mod

  For example usage, see mp_loadformat.test.sas

  @param [in] libcat The format catalog to be loaded
  @param [in] libds The staging table to load
  @param [in] loadtarget= (NO) Set to YES to actually load the target catalog
  @param [in] delete_col= (_____DELETE__THIS__RECORD_____) The column used to
    mark a record for deletion.  Values should be "Yes" or "No".
  @param [out] auditlibds= (0) For change tracking, set to the libds of an audit
    table as defined in mddl_dc_difftable.sas
  @param [in] locklibds= (0) For multi-user (parallel) situations, set to the
    libds of the DC lock table as defined in the mddl_dc_locktable.sas macro.
  @param [out] outds_add= (0) Set a libds here to see the new records added
  @param [out] outds_del= (0) Set a libds here to see the records deleted
  @param [out] outds_mod= (0) Set a libds here to see the modified records
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages and preserve outputs

  <h4> SAS Macros </h4>
  @li mddl_sas_cntlout.sas
  @li mf_getuniquename.sas
  @li mf_nobs.sas
  @li mp_abort.sas
  @li mp_lockanytable.sas

  <h4> Related Macros </h4>
  @li mddl_dc_difftable.sas
  @li mddl_dc_locktable.sas
  @li mp_loadformat.test.sas
  @li mp_lockanytable.sas
  @li mp_storediffs.sas
  @li mp_stackdiffs.sas


  @version 9.2
  @author Allan Bowe

**/

%macro mp_loadformat(libcat,libds
  ,loadtarget=NO
  ,auditlibds=0
  ,locklibds=0
  ,delete_col=_____DELETE__THIS__RECORD_____
  ,outds_add=0
  ,outds_del=0
  ,outds_mod=0
  ,mdebug=0
);
/* set up local macro variables and temporary tables (with a prefix) */
%local err msg prefix dslist i var fmtlist ibufsize;
%let dslist=base base_fmts template inlibds ds1 stagedata storediffs;
%if &outds_add=0 %then %let dslist=&dslist outds_add;
%if &outds_del=0 %then %let dslist=&dslist outds_del;
%if &outds_mod=0 %then %let dslist=&dslist outds_mod;
%let prefix=%substr(%mf_getuniquename(),1,22);
%do i=1 %to %sysfunc(countw(&dslist));
  %let var=%scan(&dslist,&i);
  %local &var;
  %let &var=%upcase(&prefix._&var);
%end;


/* perform input validations */
%let err=0;
%let msg=0;
data _null_;
  if _n_=1 then putlog "&sysmacroname entry vars:";
  set sashelp.vmacro;
  where scope="&sysmacroname";
  value=upcase(value);
  if &mdebug=0 then put name '=' value;
  if name=:'LOAD' and value not in ('YES','NO') then do;
    call symputx('msg',"invalid value for "!!name!!":"!!value);
    call symputx('err',1);
    stop;
  end;
  else if name='LIBCAT' then do;
    if exist(value,'CATALOG') le 0 then do;
      call symputx('msg',"Unable to open catalog: "!!value);
      call symputx('err',1);
      stop;
    end;
  end;
  else if name='LIBDS' then do;
    if exist(value) le 0 then do;
      call symputx('msg',"Unable to open staging table: "!!value);
      call symputx('err',1);
      stop;
    end;
  end;
  else if (name=:'OUTDS' or name in ('DELETE_COL','LOCKLIBDS','AUDITLIBDS'))
  and missing(value) then do;
    call symputx('msg',"missing value in var: "!!name);
    call symputx('err',1);
    stop;
  end;
run;

%mp_abort(
  iftrue=(&err ne 0)
  ,mac=&sysmacroname
  ,msg=%str(&msg)
)

/**
  * First, extract only relevant formats from the catalog
  */
proc sql noprint;
select distinct fmtname into: fmtlist separated by ' ' from &libds;
proc format lib=&libcat cntlout=&base;
  select
  /* send formats individually to avoid line truncation in the input stack */
  %do i=1 %to %sysfunc(countw(&fmtlist));
    %scan(&fmtlist,&i,%str( ))
  %end;
  ;
run;
proc sort data=&base;
  by fmtname start;
run;

/**
  * Ensure input table and base_formats have consistent lengths and types
  */
%mddl_sas_cntlout(libds=&template)
data &inlibds;
  if 0 then set &template;
  set &libds;
  if missing(type) then do;
    if substr(fmtname,1,1)='$' then type='C';
    else type='N';
  end;
  if type='N' then start=put(input(start,best.),best16.);
run;
data &base_fmts;
  if 0 then set &template;
  set &base;
run;

/*
format values can be up to 32767 wide.  SQL joins on such a wide column can
cause buffer issues.  Update ibufsize and reset at the end.
*/
%let ibufsize=%sysfunc(getoption(ibufsize));
options ibufsize=32767 ;

/**
  * Identify new records
  */
proc sql;
create table &outds_add(drop=&delete_col) as
  select a.*
  from &inlibds a
  left join &base_fmts b
  on a.fmtname=b.fmtname
    and a.start=b.start
  where b.fmtname is null
    and upcase(a.&delete_col) ne "YES"
  order by fmtname, start;;

/**
  * Identify deleted records
  */
create table &outds_del(drop=&delete_col) as
  select a.*
  from &inlibds a
  inner join &base_fmts b
  on a.fmtname=b.fmtname
    and a.start=b.start
  where upcase(a.&delete_col)="YES"
  order by fmtname, start;

/**
  * Identify modified records
  */
create table &outds_mod (drop=&delete_col) as
  select a.*
  from &inlibds a
  inner join &base_fmts b
  on a.fmtname=b.fmtname
    and a.start=b.start
  where upcase(a.&delete_col) ne "YES"
  order by fmtname, start;

options ibufsize=&ibufsize;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(SYSCC=&syscc prior to load prep)
)

%if &loadtarget=YES %then %do;
  data &ds1;
    merge &base_fmts(in=base)
      &outds_mod(in=mod)
      &outds_add(in=add)
      &outds_del(in=del);
    if not del and not mod;
    by fmtname start;
  run;
  data &stagedata;
    set &ds1 &outds_mod;
  run;
  proc sort;
    by fmtname start;
  run;
%end;
/* mp abort needs to run outside of conditional blocks */
%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(SYSCC=&syscc prior to actual load)
)
%if &loadtarget=YES %then %do;
  %if %mf_nobs(&stagedata)=0 %then %do;
    %put There are no changes to load in &libcat!;
    %return;
  %end;
  %if &locklibds ne 0 %then %do;
    /* prevent parallel updates */
    %mp_lockanytable(LOCK,
      lib=%scan(&libcat,1,.)
      ,ds=%scan(&libcat,2,.)
      ,ref=MP_LOADFORMAT commencing format load
      ,ctl_ds=&locklibds
    )
  %end;
  /* do the actual load */
  proc format lib=&libcat cntlin=&stagedata;
  run;
  %if &locklibds ne 0 %then %do;
    /* unlock the table */
    %mp_lockanytable(UNLOCK
      lib=%scan(&libcat,1,.)
      ,ds=%scan(&libcat,2,.)
      ,ref=MP_LOADFORMAT completed format load
      ,ctl_ds=&locklibds
    )
  %end;
  /* track the changes */
  %if &auditlibds ne 0 %then %do;
    %if &locklibds ne 0 %then %do;
      %mp_lockanytable(LOCK,
        lib=%scan(&auditlibds,1,.)
        ,ds=%scan(&auditlibds,2,.)
        ,ref=MP_LOADFORMAT commencing audit table load
        ,ctl_ds=&locklibds
      )
    %end;

    %mp_storediffs(&libcat
      ,&stageds
      ,FMTNAME START
      ,delds=&outds_del
      ,modds=&outds_mod
      ,appds=&outds_add
      ,outds=&storediffs
      ,mdebug=&mdebug
    )

    %if &locklibds ne 0 %then %do;
      %mp_lockanytable(UNLOCK
        lib=%scan(&auditlibds,1,.)
        ,ds=%scan(&auditlibds,2,.)
        ,ref=MP_LOADFORMAT commencing audit table load
        ,ctl_ds=&locklibds
      )
    %end;
  %end;
%end;
%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(SYSCC=&syscc after load)
)

%if &mdebug=0 %then %do;
  proc datasets lib=work;
    delete &prefix:;
  run;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;
%mend mp_loadformat;