/**
  @file
  @brief Prepares an audit table for stacking (re-applying) the changes.
  @details WORK IN PROGRESS!!

    When the underlying data from a Base Table is refreshed, it can be helpful
    to have any previously-applied changes, re-applied.

    Such situation might arise if you are applying those changes using a tool
    like [Data Controller for SAS®](https://datacontroller.io) - which records
    all such changes in an audit table.
    It may also apply if you are preparing a series of specific cell-level
    transactions, that you would like to apply to multiple sets of (similarly
    structured) Base Tables.

    In both cases, it is necessary that the transactions are stored using
    the mp_storediffs.sas macro, or at least that the underlying table is
    structured as per the definition in mp_coretable.sas (DIFFTABLE entry)

    <b>This</b> macro is used to convert the stored changes (tall format) into
    staged changes (wide format), with base table values incorporated (in the
    case of modified rows), ready for the subsequent load process.

    Essentially then, what this macro does, is turn a table like this:

  |MOVE_TYPE:$1.|TGTVAR_NM:$32.|IS_PK:best.|IS_DIFF:best.|TGTVAR_TYPE:$1.|OLDVAL_NUM:best32.|NEWVAL_NUM:best32.|OLDVAL_CHAR:$32765.|NEWVAL_CHAR:$32765.|
  |---|---|---|---|---|---|---|---|---|
  |`A `|`NAME `|`1 `|`-1 `|`C `|`. `|`. `|` `|`Newbie `|
  |`A `|`AGE `|`0 `|`-1 `|`N `|`. `|`13 `|` `|` `|
  |`A `|`HEIGHT `|`0 `|`-1 `|`N `|`. `|`65.3 `|` `|` `|
  |`A `|`SEX `|`0 `|`-1 `|`C `|`. `|`. `|` `|`F `|
  |`A `|`WEIGHT `|`0 `|`-1 `|`N `|`. `|`98 `|` `|` `|
  |`D `|`NAME `|`1 `|`-1 `|`C `|`. `|`. `|`Alfred `|` `|
  |`D `|`AGE `|`0 `|`-1 `|`N `|`14 `|`. `|` `|` `|
  |`D `|`HEIGHT `|`0 `|`-1 `|`N `|`69 `|`. `|` `|` `|
  |`D `|`SEX `|`0 `|`-1 `|`C `|`. `|`. `|`M `|` `|
  |`D `|`WEIGHT `|`0 `|`-1 `|`N `|`112.5 `|`. `|` `|` `|
  |`M `|`NAME `|`1 `|`0 `|`C `|`. `|`. `|`Alice `|`Alice `|
  |`M `|`AGE `|`0 `|`1 `|`N `|`13 `|`99 `|` `|` `|
  |`M `|`HEIGHT `|`0 `|`0 `|`N `|`56.5 `|`56.5 `|` `|` `|
  |`M `|`SEX `|`0 `|`0 `|`C `|`. `|`. `|`F `|`F `|
  |`M `|`WEIGHT `|`0 `|`0 `|`N `|`84 `|`84 `|` `|` `|

    Into three tables like this:

  <b> `work.outmod`: </b>
  |NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|
  |---|---|---|---|---|
  |`Alice `|`F `|`99 `|`56.5 `|`84 `|

  <b> `work.outadd`: </b>
  |NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|
  |---|---|---|---|---|
  |`Newbie `|`F `|`13 `|`65.3 `|`98 `|

  <b> `work.outdel`: </b>
  |NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|
  |---|---|---|---|---|
  |`Alfred `|`M `|`14 `|`69 `|`112.5 `|

    As you might expect, there are a bunch of extra features and checks.

    The macro supports both SCD2 (TXTEMPORAL) and UPDATE loadtypes. If the
    base table contains a PROCESSED_DTTM column (or similar), this can be
    ignored by declaring it in the `processed_dttm_var` parameter.

    The macro is also flexible where columns have been added or removed from
    the base table UNLESS there is a change to the primary key.

    Changes to the primary key are NOT supported, and are likely to cause
    unexpected results.

    The following pre-flight checks are made:

    @li All primary key columns exist on the base table
    @li There is no change in variable TYPE for any of the columns
    @li There is no reduction in variable LENGTH below the max-length of the
      supplied values

    Rules for stacking changes are as follows:

    <table>
    <tr>
      <th>Transaction Type</th><th>Key Behaviour</th><th>Column Behaviour</th>
    </tr>
    <tr>
      <td>Deletes</td>
      <td>
        The row is added to `&outDEL.` UNLESS it no longer exists
        in the base table, in which case it is added to `&errDS.` instead.
      </td>
      <td>
        Deletes are unaffected by the addition or removal of non Primary-Key
        columns.
      </td>
    </tr>
    <tr>
      <td>Inserts</td>
      <td>
        Previously newly added rows are added to the `outADD` table UNLESS they
        are present in the Base table.<br>In this case they are added to the
        `&errDS.` table instead.
      </td>
      <td>
        Inserts are unaffected by the addition of columns in the Base Table
        (they are padded with blanks).  Deleted columns are only a problem if
        they appear on the previous insert - in which case the record is added
        to `&errDS.`.
      </td>
    </tr>
    <tr>
      <td>Updates</td>
      <td>
        Previously modified rows are merged with base table values such that
        only the individual cells that were _previously_ changed are re-applied.
        Where the row contains cells that were not marked as having changed in
        the prior transaction, the 'blanks' are filled with base table values in
        the `outMOD` table.<br>
        If the row no longer exists on the base table, then the row is added to
        the `errDS` table instead.
      </td>
      <td>
        Updates are unaffected by the addition of columns in the Base Table -
        the new cells are simply populated with Base Table values.  Deleted
        columns are only a problem if they relate to a modified cell
        (`is_diff=1`) - in which case the record is added to `&errDS.`.
      </td>
    </tr>
    </table>

    To illustrate the above with a diagram:

  @dot
    digraph {
      rankdir="TB"
      start[label="Transaction Type?" shape=Mdiamond]
      del[label="Does Base Row exist?" shape=rectangle]
      add [label="Does Base Row exist?" shape=rectangle]
      mod [label="Does Base Row exist?" shape=rectangle]
      chkmod [label="Do all modified\n(is_diff=1) cells exist?" shape=rectangle]
      chkadd [label="Do all inserted cells exist?" shape=rectangle]
      outmod [label="outMOD\nTable" shape=Msquare style=filled]
      outadd [label="outADD\nTable" shape=Msquare style=filled]
      outdel [label="outDEL\nTable" shape=Msquare style=filled]
      outerr [label="ErrDS Table" shape=Msquare fillcolor=Orange style=filled]
      start -> del [label="Delete"]
      start -> add [label="Insert"]
      start -> mod [label="Update"]

      del -> outdel [label="Yes"]
      del -> outerr [label="No" color="Red" fontcolor="Red"]
      add -> chkadd [label="No"]
      add -> outerr [label="Yes" color="Red" fontcolor="Red"]
      mod -> outerr [label="No" color="Red" fontcolor="Red"]
      mod -> chkmod [label="Yes"]
      chkmod -> outerr [label="No" color="Red" fontcolor="Red"]
      chkmod -> outmod [label="Yes"]
      chkadd -> outerr [label="No" color="Red" fontcolor="Red"]
      chkadd -> outadd [label="Yes"]

    }
  @enddot

    For examples of usage, check out the mp_stackdiffs.test.sas program.


  @param [in] baselibds Base Table against which the changes will be applied,
    in libref.dataset format.
  @param [in] auditlibds Dataset with previously applied transactions, to be
    re-applied. Use libref.dataset format.
    DDL as follows:  %mp_coretable(DIFFTABLE)
  @param [in] key Space seperated list of key variables
  @param [in] mdebug= Set to 1 to enable DEBUG messages and preserve outputs
  @param [in] processed_dttm_var= (0) If a variable is being used to mark
    the processed datetime, put the name of the variable here.  It will NOT
    be included in the staged dataset (the load process is expected to
    provide this)
  @param [out] errds= (work.errds) Output table containing problematic records.
    The columns of this table are:
    @li PK_VARS - Space separated list of primary key variable names
    @li PK_VALS - Slash separted list of PK variable values
    @li ERR_MSG - Explanation of why this record is problematic
  @param [out] outmod= (work.outmod) Output table containing modified records
  @param [out] outadd= (work.outadd) Output table containing additional records
  @param [out] outdel= (work.outdel) Output table containing deleted records


  <h4> SAS Macros </h4>
  @li mf_existvarlist.sas
  @li mf_getquotedstr.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_islibds.sas
  @li mf_nobs.sas
  @li mf_wordsinstr1butnotstr2.sas
  @li mp_abort.sas
  @li mp_ds2squeeze.sas


  <h4> Related Macros </h4>
  @li mp_coretable.sas
  @li mp_stackdiffs.test.sas
  @li mp_storediffs.sas

  @todo The current approach assumes that a variable called KEY_HASH is not on
    the base table.  This part will need to be refactored (eg using
    mf_getuniquename.sas) when such a use case arises.

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mp_stackdiffs(baselibds
  ,auditlibds
  ,key
  ,mdebug=0
  ,processed_dttm_var=0
  ,errds=work.errds
  ,outmod=work.outmod
  ,outadd=work.outadd
  ,outdel=work.outdel
)/*/STORE SOURCE*/;
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

/* input parameter validations */
%mp_abort(iftrue= (%mf_islibds(&baselibds) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(Invalid baselibds: &baselibds)
)
%mp_abort(iftrue= (%mf_islibds(&auditlibds) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(Invalid auditlibds: &auditlibds)
)
%mp_abort(iftrue= (%length(&key)=0)
  ,mac=&sysmacroname
  ,msg=%str(Missing key variables!)
)
%mp_abort(iftrue= (
    %mf_existVarList(&auditlibds,LIBREF DSN MOVE_TYPE KEY_HASH TGTVAR_NM IS_PK
      IS_DIFF TGTVAR_TYPE OLDVAL_NUM NEWVAL_NUM OLDVAL_CHAR NEWVAL_CHAR)=0
  )
  ,mac=&sysmacroname
  ,msg=%str(Input &auditlibds is missing required columns!)
)


/* set up macro vars */
%local prefix dslist x var keyjoin commakey keepvars missvars fref;
%let prefix=%substr(%mf_getuniquename(),1,25);
%let dslist=ds1d ds2d ds3d ds1a ds2a ds3a ds1m ds2m ds3m pks dups base
  delrec delerr addrec adderr modrec moderr;
%do x=1 %to %sysfunc(countw(&dslist));
  %let var=%scan(&dslist,&x);
  %local &var;
  %let &var=%upcase(&prefix._&var);
%end;

%let key=%upcase(&key);
%let commakey=%mf_getquotedstr(&key,quote=N);

%let keyjoin=1=1;
%do x=1 %to %sysfunc(countw(&key));
  %let var=%scan(&key,&x);
  %let keyjoin=&keyjoin and a.&var=b.&var;
%end;

data &errds;
  length pk_vars $256 pk_vals $4098 err_msg $512;
  call missing (of _all_);
  stop;
run;

/**
  * Prepare raw DELETE table
  * Records are in the OLDVAL_xxx columns
  */
%let keepvars=MOVE_TYPE KEY_HASH TGTVAR_NM TGTVAR_TYPE IS_PK
              OLDVAL_NUM OLDVAL_CHAR
              NEWVAL_NUM NEWVAL_CHAR;
proc sort data=&auditlibds(where=(move_type='D') keep=&keepvars)
  out=&ds1d(drop=move_type);
by KEY_HASH TGTVAR_NM;
run;
proc transpose data=&ds1d(where=(tgtvar_type='N'))
    out=&ds2d(drop=_name_);
  by KEY_HASH;
  id TGTVAR_NM;
  var OLDVAL_NUM;
run;
proc transpose data=&ds1d(where=(tgtvar_type='C'))
    out=&ds3d(drop=_name_);
  by KEY_HASH;
  id TGTVAR_NM;
  var OLDVAL_CHAR;
run;
%mp_ds2squeeze(&ds2d,outds=&ds2d)
%mp_ds2squeeze(&ds3d,outds=&ds3d)
data &outdel;
  if 0 then set &baselibds;
  set &ds2d;
  set &ds3d;
  drop key_hash;
  if not missing(%scan(&key,1));
run;
proc sort;
  by &key;
run;

/**
  * Prepare raw APPEND table
  * Records are in the NEWVAL_xxx columns
  */
proc sort data=&auditlibds(where=(move_type='A') keep=&keepvars)
    out=&ds1a(drop=move_type);
  by KEY_HASH TGTVAR_NM;
run;
proc transpose data=&ds1a(where=(tgtvar_type='N'))
    out=&ds2a(drop=_name_);
  by KEY_HASH;
  id TGTVAR_NM;
  var NEWVAL_NUM;
run;
proc transpose data=&ds1a(where=(tgtvar_type='C'))
    out=&ds3a(drop=_name_);
  by KEY_HASH;
  id TGTVAR_NM;
  var NEWVAL_CHAR;
run;
%mp_ds2squeeze(&ds2a,outds=&ds2a)
%mp_ds2squeeze(&ds3a,outds=&ds3a)
data &outadd;
  if 0 then set &baselibds;
  set &ds2a;
  set &ds3a;
  drop key_hash;
  if not missing(%scan(&key,1));
run;
proc sort;
  by &key;
run;

/**
  * Prepare raw MODIFY table
  * Keep only primary key - will add modified values later
  */
proc sort data=&auditlibds(
      where=(move_type='M' and is_pk=1) keep=&keepvars
    ) out=&ds1m(drop=move_type);
  by KEY_HASH TGTVAR_NM;
run;
proc transpose data=&ds1m(where=(tgtvar_type='N'))
    out=&ds2m(drop=_name_);
  by KEY_HASH ;
  id TGTVAR_NM;
  var NEWVAL_NUM;
run;
proc transpose data=&ds1m(where=(tgtvar_type='C'))
    out=&ds3m(drop=_name_);
  by KEY_HASH;
  id TGTVAR_NM;
  var NEWVAL_CHAR;
run;
%mp_ds2squeeze(&ds2m,outds=&ds2m)
%mp_ds2squeeze(&ds3m,outds=&ds3m)
data &outmod;
  if 0 then set &baselibds;
  set &ds2m;
  set &ds3m;
  if not missing(%scan(&key,1));
run;
proc sort;
  by &key;
run;

/**
  * Extract matching records from the base table
  * Do this in one join for efficiency.
  * At a later date, this should be optimised for large database tables by using
  * passthrough and a temporary table.
  */
data &pks;
  if 0 then set &baselibds;
  set &outadd &outmod &outdel;
  keep &key;
run;

proc sort noduprec dupout=&dups;
by &key;
run;
data _null_;
  set &dups;
  putlog (_all_)(=);
run;
%mp_abort(iftrue= (%mf_nobs(&dups) ne 0)
  ,mac=&sysmacroname
  ,msg=%str(duplicates (%mf_nobs(&dups)) found on &auditlibds!)
)

proc sql;
create table &base as
  select a.*
  from &baselibds a, &pks b
  where &keyjoin;

/**
  * delete check
  * This is straightforward as it relates to records only
  */
proc sql;
create table &delrec as
  select a.*
  from &outdel a
  left join &base b
  on &keyjoin
  where a.%scan(&key,1) is null
  order by &commakey;

data &delerr;
  if 0 then set &errds;
  set &delrec;
  PK_VARS="&key";
  PK_VALS=catx('/',&commakey);
  ERR_MSG="Rows cannot be deleted as they do not exist on the Base dataset";
  keep PK_VARS PK_VALS ERR_MSG;
run;
proc append base=&errds data=&delerr;
run;

data &outdel;
  merge &outdel (in=a) &delrec (in=b);
  by &key;
  if not b;
run;

/**
  * add check
  * Problems - where record already exists, or base table has columns missing
  */
%let missvars=%mf_wordsinstr1butnotstr2(
  Str1=%upcase(%mf_getvarlist(&outadd)),
  Str2=%upcase(%mf_getvarlist(&baselibds))
);
%if %length(&missvars)>0 %then %do;
    /* add them to the err table */
  data &adderr;
    if 0 then set &errds;
    set &outadd;
    PK_VARS="&key";
    PK_VALS=catx('/',&commakey);
    ERR_MSG="Rows cannot be added due to missing base vars: &missvars";
    keep PK_VARS PK_VALS ERR_MSG;
  run;
  proc append base=&errds data=&adderr;
  run;
  proc sql;
  delete * from &outadd;
%end;
%else %do;
  proc sql;
  /* find records that already exist on base table */
  create table &addrec as
    select a.*
    from &outadd a
    inner join &base b
    on &keyjoin
    order by &commakey;

  /* add them to the err table */
  data &adderr;
    if 0 then set &errds;
    set &addrec;
    PK_VARS="&key";
    PK_VALS=catx('/',&commakey);
    ERR_MSG="Rows cannot be added as they already exist on the Base dataset";
    keep PK_VARS PK_VALS ERR_MSG;
  run;
  proc append base=&errds data=&adderr;
  run;

  /* remove invalid rows from the outadd table */
  data &outadd;
    merge &outadd (in=a) &addrec (in=b);
    by &key;
    if not b;
  run;
%end;

/**
  * mod check
  * Problems - where record does not exist or baseds has modified cols missing
  */
proc sql noprint;
select distinct tgtvar_nm into: missvars separated by ' '
  from &auditlibds
  where move_type='M' and is_diff=1;
%let missvars=%mf_wordsinstr1butnotstr2(
  Str1=&missvars,
  Str2=%upcase(%mf_getvarlist(&baselibds))
);
%if %length(&missvars)>0 %then %do;
    /* add them to the err table */
  data &moderr;
    if 0 then set &errds;
    set &outmod;
    PK_VARS="&key";
    PK_VALS=catx('/',&commakey);
    ERR_MSG="Rows cannot be modified due to missing base vars: &missvars";
    keep PK_VARS PK_VALS ERR_MSG;
  run;
  proc append base=&errds data=&moderr;
  run;
  proc sql;
  delete * from &outmod;
%end;
%else %do;
  /* now check for records that do not exist (therefore cannot be modified) */
  proc sql;
  create table &modrec as
    select a.*
    from &outmod a
    left join &base b
    on &keyjoin
    where a.%scan(&key,1) is null
    order by &commakey;
  data &moderr;
    if 0 then set &errds;
    set &modrec;
    PK_VARS="&key";
    PK_VALS=catx('/',&commakey);
    ERR_MSG="Rows cannot be modified as they do not exist on the Base dataset";
    keep PK_VARS PK_VALS ERR_MSG;
  run;
  proc append base=&errds data=&moderr;
  run;
  /* delete the above records from the outmod table */
  data &outmod;
    merge &outmod (in=a) &modrec (in=b);
    by &key;
    if not b;
  run;
  /* now - we can prepare the final MOD table (which is currently PK only) */
  proc sql undo_policy=none;
  create table &outmod as
    select a.key_hash
      ,b.*
    from &outmod a
    inner join &base b
    on &keyjoin
    order by &commakey;
  /* now - to update outmod with modified (is_diff=1) values */
  %let fref=%mf_getuniquefileref();
  data _null_;
    file &fref;
    set &auditlibds(where=(move_type='M')) end=lastobs;
    by key_hash;
    if _n_=1 then put 'proc sql;';
    if first.key_hash then put "update &outmod set " / '  '@@;
    else put '  ,'@@;
    if is_diff=1 then do;
      if tgtvar_type='C' then do;
        length qstr $32767;
        qstr=quote(trim(NEWVAL_CHAR));
        put tgtvar_nm '=' qstr;
      end;
      else put tgtvar_nm '=' newval_num;
    end;
    if last.key_hash then put '  where key_hash=trim("' key_hash '");';
    if lastobs then put "alter table &outmod drop key_hash;";
  run;
  %inc &fref/source2;
%end;

%if &mdebug=0 %then %do;
  proc datasets lib=work;
    delete &prefix:;
  run;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;
%mend mp_stackdiffs;
/** @endcond */