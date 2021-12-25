/**
  @file
  @brief Generate and apply retained key values to a staging table
  @details This macro will populate a staging table with a Retained Key based on
  a business key and a base (target) table.

  Definition of retained key ([source](
    http://bukhantsov.org/2012/04/what-is-data-vault/)):

  > The retained key is a key which is mapped to business key one-to-one. In
  > comparison,  the surrogate key includes time and there can be many surrogate
  > keys corresponding to one business key. This explains the name of the key,
  > it is retained with insertion of a new version of a row while surrogate key
  > is increasing.

  This macro is designed to be used as part of a wider load / ETL process (such
  as the one in [Data Controller for SAS](https://datacontroller.io)).

  Specifically, the macro assumes that the base table has already been 'locked'
  (eg with the mp_lockanytable.sas macro) prior to invocation.  Also, several
  tables are assumed to exist (names are configurable):

  @li work.staging_table - the staged data, minus the retained key element
  @li permlib.base_table - the target table to be loaded (**not** loaded by this
    macro)
  @li permlib.maxkeytable - optional, used to store load metaadata.
  The structure is as follows:

      proc sql;
      create table yourlib.maxkeytable(
          keytable varchar(41) label='Base table in libref.dataset format',
          keycolumn char(32) format=$32.
            label='The Retained key field containing the key values.',
          max_key num label=
            'Integer representing current max RK or SK value in the KEYTABLE',
          processed_dttm num format=E8601DT26.6
            label='Datetime this value was last updated',
        constraint pk_mpe_maxkeyvalues
            primary key(keytable));

  @param [in] base_lib= (WORK) Libref of the base (target) table.
  @param [in] base_dsn= (BASETABLE) Name of the base (target) table.
  @param [in] append_lib= (WORK) Libref of the staging table
  @param [in] append_dsn= (APPENDTABLE) Name of the staging table
  @param [in] retained_key= (DEFAULT_RK) Name of RK to generate (should exist on
    base table)
  @param [in] business_key= (PK1 PK2) Business key against which to generate
    RK values.  Should be unique and not null on the staging table.
  @param [in] check_uniqueness=(NO) Set to yes to perform a uniqueness check.
    Recommended if there is a chance that the staging data is not unique on the
    business key.
  @param [in] maxkeytable= (0) Provide a maxkeytable libds reference here, to
    store load metadata (maxkey val, load time).  Set to zero if metadata is not
    required, eg, when preparing a 'dummy' load. Structure is described above.
    See below for sample data.
    |KEYTABLE:$32.|KEYCOLUMN:$32.|MAX_KEY:best.|PROCESSED_DTTM:E8601DT26.6|
    |---|---|---|---|
    |`DC487173.MPE_SELECTBOX `|`SELECTBOX_RK `|`55 `|`1950427787.8 `|
    |`DC487173.MPE_FILTERANYTABLE `|`filter_rk `|`14 `|`1951053886.8 `|
  @param [in] locktable= (0) If updating the maxkeytable, provide the libds
    reference to the lock table (per mp_lockanytable.sas macro)
  @param [in] filter_str= Apply a filter - useful for SCD2 or BITEMPORAL loads.
    Example: `filter_str=%str( (where=( &now < &tech_to)) )`
  @param [out] outds= (WORK.APPEND) Output table (staging table + retained key)

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_getquotedstr.sas
  @li mf_getuniquename.sas
  @li mf_nobs.sas
  @li mp_abort.sas
  @li mp_lockanytable.sas

  <h4> Related Macros </h4>
  @li mp_retainedkey.test.sas

  @version 9.2

**/

%macro mp_retainedkey(
  base_lib=WORK
  ,base_dsn=BASETABLE
  ,append_lib=WORK
  ,append_dsn=APPENDTABLE
  ,retained_key=DEFAULT_RK
  ,business_key= PK1 PK2
  ,check_uniqueness=NO
  ,maxkeytable=0
  ,locktable=0
  ,outds=WORK.APPEND
  ,filter_str=
);
%put &sysmacroname entry vars:;
%put _local_;

%local base_libds app_libds key_field check maxkey idx_pk newkey_cnt iserr
  msg x tempds1 tempds2 comma_pk appnobs checknobs dropvar tempvar idx_val;
%let base_libds=%upcase(&base_lib..&base_dsn);
%let app_libds=%upcase(&append_lib..&append_dsn);
%let tempds1=%mf_getuniquename();
%let tempds2=%mf_getuniquename();
%let comma_pk=%mf_getquotedstr(in_str=%str(&business_key),dlm=%str(,),quote=);

/* validation checks */
%let iserr=0;
%if &syscc>0 %then %do;
  %let iserr=1;
  %let msg=%str(SYSCC=&syscc on macro entry);
%end;
%else %if %sysfunc(exist(&base_libds))=0 %then %do;
  %let iserr=1;
  %let msg=%str(Base LIBDS (&base_libds) expected but NOT FOUND);
%end;
%else %if %sysfunc(exist(&app_libds))=0 %then %do;
  %let iserr=1;
  %let msg=%str(Append LIBDS (&app_libds) expected but NOT FOUND);
%end;
%else %if &maxkeytable ne 0 and %sysfunc(exist(&maxkeytable))=0  %then %do;
  %let iserr=1;
  %let msg=%str(Maxkeytable (&maxkeytable) expected but NOT FOUND);
%end;
%else %if &maxkeytable ne 0 and %sysfunc(exist(&locktable))=0  %then %do;
  %let iserr=1;
  %let msg=%str(Locktable (&locktable) expected but NOT FOUND);
%end;
%else %if %length(&business_key)=0 %then %do;
  %let iserr=1;
  %let msg=%str(Business key (&business_key) expected but NOT FOUND);
%end;

%do x=1 %to %sysfunc(countw(&business_key));
  /* check business key values exist */
  %let key_field=%scan(&business_key,&x,%str( ));
  %if (not %mf_existvar(&app_libds,&key_field))
    or (not %mf_existvar(&base_libds,&key_field))
  %then %do;
    %let iserr=1;
    %let msg=Business key (&key_field) not found!;
  %end;
%end;

%if &iserr=1 %then %do;
  /* err case so first perform an unlock of the base table before exiting */
  %mp_lockanytable(
    UNLOCK,lib=&base_lib,ds=&base_dsn,ref=%superq(msg),ctl_ds=&locktable
  )
%end;
%mp_abort(iftrue=(&iserr=1),mac=mp_retainedkey,msg=%superq(msg))

proc sql noprint;
select sum(max(&retained_key),0) into: maxkey from &base_libds;

/**
  * get base table RK and bus field values for lookup
  */
proc sql noprint;
create table &tempds1 as
  select distinct &comma_pk,&retained_key
  from &base_libds &filter_str
  order by &comma_pk,&retained_key;

%if &check_uniqueness=YES %then %do;
  select count(*) into:checknobs
    from (select distinct &comma_pk from &app_libds);
  select count(*) into: appnobs from &app_libds; /* might be view */
  %if &checknobs ne &appnobs %then %do;
    %let msg=Source table &app_libds is not unique on (&business_key);
    %let iserr=1;
  %end;
%end;
%if &iserr=1 %then %do;
  /* err case so first perform an unlock of the base table before exiting */
  %mp_lockanytable(
    UNLOCK,lib=&base_lib,ds=&base_dsn,ref=%superq(msg),ctl_ds=&locktable
  )
%end;
%mp_abort(iftrue= (&iserr=1),mac=mp_retainedkey,msg=%superq(msg))

%if %mf_existvar(&app_libds,&retained_key)
%then %let dropvar=(drop=&retained_key);

/* prepare interim table with retained key populated for matching keys */
proc sql noprint;
create table &tempds2 as
  select b.&retained_key, a.*
  from &app_libds &dropvar a
  left join &tempds1 b
  on 1
  %do idx_pk=1 %to %sysfunc(countw(&business_key));
    %let idx_val=%scan(&business_key,&idx_pk);
    and a.&idx_val=b.&idx_val
  %end;
  order by &retained_key;

/* identify the number of entries without retained keys (new records) */
select count(*) into: newkey_cnt
  from &tempds2
  where missing(&retained_key);
quit;

/**
  * Update maxkey table if link provided
  */
%if &maxkeytable ne 0 %then %do;
  proc sql;
  select count(*) into: check from &maxkeytable
    where upcase(keytable)="&base_libds";

  %mp_lockanytable(LOCK
    ,lib=%scan(&maxkeytable,1,.)
    ,ds=%scan(&maxkeytable,2,.)
    ,ref=Updating maxkeyvalues with mp_retainedkey
    ,ctl_ds=&locktable
  )
  proc sql;
  %if &check=0 %then %do;
  insert into &maxkeytable
    set keytable="&base_libds"
      ,keycolumn="&retained_key"
      ,max_key=%eval(&maxkey+&newkey_cnt)
      ,processed_dttm="%sysfunc(datetime(),E8601DT26.6)"dt;
  %end;
  %else %do;
  update &maxkeytable
    set max_key=%eval(&maxkey+&newkey_cnt)
      ,processed_dttm="%sysfunc(datetime(),E8601DT26.6)"dt
    where keytable="&base_libds";
  %end;
  %mp_lockanytable(UNLOCK
    ,lib=%scan(&maxkeytable,1,.)
    ,ds=%scan(&maxkeytable,2,.)
    ,ref=Updating maxkeyvalues with maxkey=%eval(&maxkey+&newkey_cnt)
    ,ctl_ds=&locktable
  )
%end;

/* fill in the missing retained key values */
%let tempvar=%mf_getuniquename();
data &outds(drop=&tempvar);
  retain &tempvar %eval(&maxkey+1);
  set &tempds2;
  if &retained_key =. then &retained_key=&tempvar;
  &tempvar=&tempvar+1;
run;

%mend mp_retainedkey;

