/**
  @file
  @brief Generates a stage dataset to revert diffs tracked in an audit table
  @details A big benefit of tracking data changes in an audit table is that
    those changes can be subsequently reverted if necessary!

    This macro prepares a staging dataset containing those differences - eg for:

    @li deleted rows - these are re-inserted
    @li changed rows - differences are reverted
    @li added rows - marked with `_____DELETE__THIS__RECORD_____="YES"`

    These changes are NOT applied to the base table - a staging dataset is
    simply prepared for an ETL process to action.  In Data Controller, this
    dataset is used directly as an input to the APPROVE process (so that the
    reversion diffs can be reviewed prior to being applied).


  @param [in] libds Base library.dataset (will not be modified).  The library
    must be assigned.
  @param [in] loadref Unique identifier for the version to be reverted.  This
    change, plus ALL SUBSEQUENT CHANGES, will be reverted in the output table.
  @param [in] difftable The dataset containing the diffs.  Definition available
    in mddl_dc_difftable.sas
  @param [out] outds= (work.mp_stripdiffs) Output table containing the diffs.
    Has the same format as the base datset, plus a
    `_____DELETE__THIS__RECORD_____` variable.
  @param [in] mdebug= set to 1 to enable DEBUG messages and preserve outputs

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_islibds.sas
  @li mp_abort.sas

  <h4> Related Macros </h4>
  @li mddl_dc_difftable.sas
  @li mp_stackdiffs.sas
  @li mp_storediffs.sas
  @li mp_stripdiffs.test.sas

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mp_stripdiffs(libds
  ,loadref
  ,difftable
  ,outds=work.mp_stripdiffs
  ,mdebug=0
)/*/STORE SOURCE*/;
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

%let libds=%upcase(&libds);

/* safety checks */
%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(SYSCC=&syscc on entry.  Clean session required!)
)
%let libds=%upcase(&libds);
%mp_abort(iftrue= (%mf_islibds(&libds)=0)
  ,mac=&sysmacroname
  ,msg=%str(Invalid library.dataset reference - %superq(libds))
)



/* set up unique and temporary vars */
%local ds1 ds2 ds3 ds4 ds5 fref1;
%let fref1=%mf_getuniquefileref();

/* get timestamp of the diff to be reverted */
%local ts;
proc sql noprint;
select put(processed_dttm,datetime19.6) into: ts
  from &difftable where load_ref="&loadref";
%mp_abort(iftrue= (&sqlobs=0)
  ,mac=&sysmacroname
  ,msg=%str(Load ref %superq(loadref) not found!)
)

/* extract diffs for this base table from this timestamp onwards */
%let ds1=%upcase(work.%mf_getuniquename(prefix=mpsd_diffs));
create table &ds1 (drop=libref dsn) as
  select * from &difftable
  where upcase(cats(libref))="%scan(&libds,1,.)"
  and upcase(cats(dsn))="%scan(&libds,2,.)"
  and processed_dttm ge "&ts"dt
  order by processed_dttm desc, key_hash, is_pk;

/* extract key values only */
%let ds2=%upcase(work.%mf_getuniquename(prefix=mpsd_pks));
create table &ds2 as
  select distinct key_hash,
    tgtvar_nm,
    tgtvar_type,
    coalescec(oldval_char,newval_char) as charval,
    coalesce(oldval_num, newval_num) as numval,
    processed_dttm
  from &ds1
  where is_pk=1
  order by key_hash, processed_dttm;

/* grab pk values */
%local pk;
data _null_;
  set &ds2;
  by key_hash processed_dttm;
  call symputx('pk',catx(' ',symget('pk'),tgtvar_nm),'l');
  if last.processed_dttm then stop;
run;

%let ds3=%upcase(work.%mf_getuniquename(prefix=mpsd_keychar));
proc transpose data=&ds2(where=(tgtvar_type='C'))
    out=&ds3(drop=_name_);
  by KEY_HASH PROCESSED_DTTM;
  id TGTVAR_NM;
  var charval;
run;

%let ds4=%upcase(work.%mf_getuniquename(prefix=mpsd_keynum));
proc transpose data=&ds2(where=(tgtvar_type='N'))
    out=&ds4(drop=_name_);
  by KEY_HASH PROCESSED_DTTM;
  id TGTVAR_NM;
  var numval;
run;
/* shorten the lengths */
%mp_ds2squeeze(&ds3,outds=&ds3)
%mp_ds2squeeze(&ds4,outds=&ds4)

/* now merge to get all key values and de-dup */
%let ds5=%upcase(work.%mf_getuniquename(prefix=mpsd_merged));
data &ds5;
  length key_hash $32 processed_dttm 8;
  merge &ds3 &ds4;
  by key_hash;
  if not missing(key_hash);
run;
proc sort data=&ds5 nodupkey;
  by &pk;
run;

/* join to base table for preliminary stage DS */
proc sql;
create table &outds as select "No " as _____DELETE__THIS__RECORD_____,
    b.*
  from &ds5 a
  inner join &libds b
  on 1=1
%do x=1 %to %sysfunc(countw(&pk,%str( )));
  and a.%scan(&pk,&x,%str( ))=b.%scan(&pk,&x,%str( ))
%end;
;

/* create SAS code to apply to stage_ds */
data _null_;
  set &ds1;
  file &fref1 lrecl=33000;
  length charval $32767;
  if _n_=1 then put 'proc sql noprint;';
  by descending processed_dttm key_hash is_pk;
  if move_type='M' then do;
    if first.key_hash then do;
      put "update &outds set " @@;
    end;
    if IS_PK=0 then do;
      put "  " tgtvar_nm '=' @@;
      cnt=count(oldval_char,'"');
      charval=quote(trim(substr(oldval_char,1,32765-cnt)));
      if tgtvar_type='C' then put charval @@;
      else put oldval_num @@;
      if not last.is_pk then put ',';
    end;
    else do;
      if first.is_pk then put "  where 1=1 " @@;
      put "  and " tgtvar_nm '=' @@;
      cnt=count(oldval_char,'"');
      charval=quote(trim(substr(oldval_char,1,32765-cnt)));
      if tgtvar_type='C' then put charval @@;
      else put oldval_num @@;
    end;
  end;
  else if move_type='A' then do;
    if first.key_hash then do;
      put "update &outds set _____DELETE__THIS__RECORD_____='Yes' where 1=1 "@@;
    end;
    /* gating if - as only need PK now */
    if is_pk=1;
    put '  AND ' tgtvar_nm '=' @@;
    cnt=count(newval_char,'"');
    charval=quote(trim(substr(newval_char,1,32765-cnt)));
    if tgtvar_type='C' then put charval @@;
    else put newval_num @@;
  end;
  else if move_type='D' then do;
    if first.key_hash then do;
      put "insert into &outds set _____DELETE__THIS__RECORD_____='No' " @@;
    end;
    put "  ," tgtvar_nm '=' @@;
    cnt=count(oldval_char,'"');
    charval=quote(trim(substr(oldval_char,1,32765-cnt)));
    if tgtvar_type='C' then put charval @@;
    else put oldval_num @@;
  end;
  if last.key_hash then put ';';
run;

/* apply the modification statements */
%inc &fref1/source2 lrecl=33000;

%if &mdebug=0 %then %do;
  proc sql;
  drop table &ds1, &ds2, &ds3, &ds4, &ds5;
  file &fref1 clear;
%end;
%else %do;
  data _null_;
    infile &fref1;
    input;
    if _n_=1 then putlog "Contents of SQL adjustments";
    putlog _infile_;
  run;
%end;

%mend mp_stripdiffs;
/** @endcond */