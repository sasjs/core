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
  @li mf_getuniquename.sas
  @li mf_nobs.sas
  @li mp_abort.sas
  @li mp_aligndecimal.sas
  @li mp_cntlout.sas
  @li mp_lockanytable.sas
  @li mp_storediffs.sas

  <h4> Related Macros </h4>
  @li mddl_dc_difftable.sas
  @li mddl_dc_locktable.sas
  @li mp_loadformat.test.1.sas
  @li mp_loadformat.test.2.sas
  @li mp_lockanytable.sas
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
%let dslist=base_fmts template inlibds ds1 stagedata storediffs del1 del2;
%if &outds_add=0 %then %let dslist=&dslist outds_add;
%if &outds_del=0 %then %let dslist=&dslist outds_del;
%if &outds_mod=0 %then %let dslist=&dslist outds_mod;
%let prefix=%substr(%mf_getuniquename(),1,21);
%do i=1 %to %sysfunc(countw(&dslist));
  %let var=%scan(&dslist,&i);
  %local &var;
  %let &var=%upcase(&prefix._&var);
%end;

/* in DC, format catalogs maybe specified in the libds with a -FC extension */
%let libcat=%scan(&libcat,1,-);

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
select distinct
  case
    when type='N' then upcase(fmtname)
    when type='C' then cats('$',upcase(fmtname))
    when type='I' then cats('@',upcase(fmtname))
    when type='J' then cats('@$',upcase(fmtname))
    else "&sysmacroname:UNHANDLED"
  end
  into: fmtlist separated by ' '
  from &libds;

%mp_cntlout(libcat=&libcat,fmtlist=&fmtlist,cntlout=&base_fmts)

/* get a hash of the row */
%local cvars nvars;
%let cvars=TYPE FMTNAME START END LABEL PREFIX FILL SEXCL EEXCL HLO DECSEP
  DIG3SEP DATATYPE LANGUAGE;
%let nvars=FMTROW MIN MAX DEFAULT LENGTH FUZZ MULT NOEDIT;
data &base_fmts/note2err;
  set &base_fmts;
  fmthash=%mp_md5(cvars=&cvars, nvars=&nvars);
run;

/**
  * Ensure input table and base_formats have consistent lengths and types
  */
data &inlibds/nonote2err;
  length &delete_col $3 FMTROW 8 start end label $32767;
  if 0 then set &base_fmts;
  set &libds;
  by type fmtname notsorted;
  if &delete_col='' then &delete_col='No';
  fmtname=upcase(fmtname);
  type=upcase(type);
  if missing(type) then do;
    if substr(fmtname,1,1)='@' then do;
      if substr(fmtname,2,1)='$' then type='J';
      else type='I';
    end;
    else do;
      if substr(fmtname,1,1)='$' then type='C';
      else type='N';
    end;
  end;
  if type in ('N','I') then do;
    %mp_aligndecimal(start,width=16)
    %mp_aligndecimal(end,width=16)
  end;

  /* update row marker - retain new var as fmtrow may already be in libds */
  if first.fmtname then row=1;
  else row+1;
  drop row;
  fmtrow=row;

  fmthash=%mp_md5(cvars=&cvars, nvars=&nvars);
run;

/**
  * Identify new records
  */
proc sql;
create table &outds_add(drop=&delete_col) as
  select a.*
  from &inlibds a
  left join &base_fmts b
  on a.type=b.type and a.fmtname=b.fmtname and a.fmtrow=b.fmtrow
  where b.fmtname is null
    and upcase(a.&delete_col) ne "YES"
  order by type, fmtname, fmtrow;

/**
  * Identify modified records
  */
create table &outds_mod (drop=&delete_col) as
  select a.*
  from &inlibds a
  inner join &base_fmts b
  on a.type=b.type and a.fmtname=b.fmtname and a.fmtrow=b.fmtrow
  where upcase(a.&delete_col) ne "YES"
    and a.fmthash ne b.fmthash
  order by type, fmtname, fmtrow;

/**
  * Identify deleted records
  */
create table &outds_del(drop=&delete_col) as
  select a.*
  from &inlibds a
  inner join &base_fmts b
  on a.type=b.type and a.fmtname=b.fmtname and a.fmtrow=b.fmtrow
  where upcase(a.&delete_col)="YES"
  order by type, fmtname, fmtrow;

/**
  * Identify fully deleted formats (where every record is removed)
  * These require to be explicitly deleted in proc format
  * del1 - identify _partial_ deletes
  * del2 - exclude these, and also formats that come with _additions_
  */
create table &del1 as
  select a.*
  from &base_fmts a
  left join &outds_del b
  on a.type=b.type and a.fmtname=b.fmtname and a.fmtrow=b.fmtrow
  where b.fmtrow is null;

create table &del2 as
  select * from &outds_del
  where cats(type,fmtname) not in (select cats(type,fmtname) from &outds_add)
    and cats(type,fmtname) not in (select cats(type,fmtname) from &del1);


%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(SYSCC=&syscc prior to load prep)
)

%if &loadtarget=YES %then %do;
  /* new records plus base records that are not deleted or modified */
  data &ds1;
    merge &base_fmts(in=base)
      &outds_mod(in=mod)
      &outds_add(in=add)
      &outds_del(in=del);
    if not del and not mod;
    by type fmtname fmtrow;
  run;
  /* add back the modified records */
  data &stagedata;
    set &ds1 &outds_mod;
  run;
  proc sort;
    by type fmtname fmtrow;
  run;
%end;
/* mp abort needs to run outside of conditional blocks */
%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(SYSCC=&syscc prior to actual load)
)
%if &loadtarget=YES %then %do;
  %if %mf_nobs(&stagedata)=0 and %mf_nobs(&del2)=0 %then %do;
    %put There are no changes to load in &libcat!;
    %return;
  %end;
  %if &locklibds ne 0 %then %do;
    /* prevent parallel updates */
    %mp_lockanytable(LOCK
      ,lib=%scan(&libcat,1,.)
      ,ds=%scan(&libcat,2,.)-FC
      ,ref=MP_LOADFORMAT commencing format load
      ,ctl_ds=&locklibds
    )
  %end;
  /* do the actual load */
  proc format lib=&libcat cntlin=&stagedata;
  run;
  /* apply any full deletes */
  %if %mf_nobs(&del2)>0 %then %do;
    %local delfmtlist;
    proc sql noprint;
    select distinct case when type='N' then cats(fmtname,'.FORMAT')
        when type='C' then cats(fmtname,'.FORMATC')
        when type='J' then cats(fmtname,'.INFMTC')
        when type='I' then cats(fmtname,'.INFMT')
        else cats(fmtname,'.BADENTRY!!!') end
      into: delfmtlist
      separated by ' '
      from &del2;
    proc catalog catalog=&libcat;
      delete &delfmtlist;
    quit;
  %end;
  %if &locklibds ne 0 %then %do;
    /* unlock the table */
    %mp_lockanytable(UNLOCK
      ,lib=%scan(&libcat,1,.)
      ,ds=%scan(&libcat,2,.)-FC
      ,ref=MP_LOADFORMAT completed format load
      ,ctl_ds=&locklibds
    )
  %end;
  /* track the changes */
  %if &auditlibds ne 0 %then %do;
    %if &locklibds ne 0 %then %do;
      %mp_lockanytable(LOCK
        ,lib=%scan(&auditlibds,1,.)
        ,ds=%scan(&auditlibds,2,.)
        ,ref=MP_LOADFORMAT commencing audit table load
        ,ctl_ds=&locklibds
      )
    %end;

    %mp_storediffs(&libcat-FC
      ,&base_fmts
      ,TYPE FMTNAME FMTROW
      ,delds=&outds_del
      ,modds=&outds_mod
      ,appds=&outds_add
      ,outds=&storediffs
      ,mdebug=&mdebug
    )

    proc append base=&auditlibds data=&storediffs;
    run;

    %if &locklibds ne 0 %then %do;
      %mp_lockanytable(UNLOCK
        ,lib=%scan(&auditlibds,1,.)
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
