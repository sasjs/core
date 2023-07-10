/**
  @file
  @brief Converts deletes/changes/appends into a single audit table.
  @details When tracking changes to data over time, it can be helpful to have
    a single base table to track ALL modifications - enabling audit trail,
    data recovery, and change re-application.  This macro is one of many
    data management utilities used in [Data Controller for SAS](
    https:datacontroller.io) - a comprehensive data ingestion solution, which
    works on any SAS platform (Viya, SAS 9, Foundation) and is free for up to 5
    users.

    NOTE - this macro does not validate the inputs. It is assumed that the
    datasets containing the new / changed / deleted rows are CORRECT, contain
    no additional (or missing columns), and that the originals dataset contains
    all relevant base records (and no additionals).

    Usage:

        data work.orig work.deleted work.changed work.appended;
          set sashelp.class;
          if _n_=1 then do;
            output work.orig work.deleted;
          end;
          else if _n_=2 then do;
            output work.orig;
            age=99;
            output work.changed;
          end;
          else do;
            name='Newbie';
            output work.appended;
            stop;
          end;
        run;

        %mp_storediffs(sashelp.class,work.orig,NAME
          ,delds=work.deleted
          ,modds=work.changed
          ,appds=work.appended
          ,outds=work.final
          ,mdebug=1
        )

  @param [in] libds Target table against which the changes were applied
  @param [in] origds Dataset with original (unchanged) records.  Can be empty if
    only appending.
  @param [in] key Space seperated list of key variables
  @param [in] delds= (0) Dataset with deleted records
  @param [in] appds= (0) Dataset with appended records
  @param [in] modds= (0) Dataset with modified records
  @param [out] outds= (work.mp_storediffs) Output table containing stored data.
    DDL as follows:  %mp_coretable(DIFFTABLE)

  @param [in] processed_dttm= (0) Provide a datetime constant in relation to
    the actual load time.  If not provided, current timestamp is used.
  @param [in] mdebug= set to 1 to enable DEBUG messages and preserve outputs
  @param [out] loadref= (0) Provide a unique key to reference the load,
    otherwise a UUID will be generated.

  <h4> SAS Macros </h4>
  @li mf_getquotedstr.sas
  @li mf_getuniquename.sas
  @li mf_getvarlist.sas

  <h4> Related Macros </h4>
  @li mp_stackdiffs.sas
  @li mp_storediffs.test.sas

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mp_storediffs(libds
  ,origds
  ,key
  ,delds=0
  ,appds=0
  ,modds=0
  ,outds=work.mp_storediffs
  ,loadref=0
  ,processed_dttm=0
  ,mdebug=0
)/*/STORE SOURCE*/;
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

/* set up unique and temporary vars */
%local ds1 ds2 ds3 ds4 hashkey inds_auto inds_keep dslist vlist;
%let ds1=%upcase(work.%mf_getuniquename(prefix=mpsd_ds1));
%let ds2=%upcase(work.%mf_getuniquename(prefix=mpsd_ds2));
%let ds3=%upcase(work.%mf_getuniquename(prefix=mpsd_ds3));
%let ds4=%upcase(work.%mf_getuniquename(prefix=mpsd_ds4));
%let hashkey=%upcase(%mf_getuniquename(prefix=mpsd_hashkey));
%let inds_auto=%upcase(%mf_getuniquename(prefix=mpsd_inds_auto));
%let inds_keep=%upcase(%mf_getuniquename(prefix=mpsd_inds_keep));

%let dslist=&origds;
%if &delds ne 0 %then %do;
  %let delds=%upcase(&delds);
  %if %scan(&delds,-1,.)=&delds %then %let delds=WORK.&delds;
  %let dslist=&dslist &delds;
%end;
%if &appds ne 0 %then %do;
  %let appds=%upcase(&appds);
  %if %scan(&appds,-1,.)=&appds %then %let appds=WORK.&appds;
  %let dslist=&dslist &appds;
%end;
%if &modds ne 0 %then %do;
  %let modds=%upcase(&modds);
  %if %scan(&modds,-1,.)=&modds %then %let modds=WORK.&modds;
  %let dslist=&dslist &modds;
%end;

%let origds=%upcase(&origds);
%if %scan(&origds,-1,.)=&origds %then %let origds=WORK.&origds;

%let key=%upcase(&key);

/* hash the key and append all the tables (marking the source) */
data &ds1;
  set &dslist indsname=&inds_auto;
  &hashkey=put(md5(catx('|',%mf_getquotedstr(&key,quote=N))),$hex32.);
  &inds_keep=upcase(&inds_auto);
proc sort;
  by &inds_keep &hashkey;
run;

/* transpose numeric & char vars */
proc transpose data=&ds1
    out=&ds2(rename=(&hashkey=key_hash _name_=tgtvar_nm col1=newval_num));
  by &inds_keep &hashkey;
  var _numeric_;
run;
proc transpose data=&ds1
    out=&ds3(
      rename=(&hashkey=key_hash _name_=tgtvar_nm col1=newval_char)
      where=(tgtvar_nm not in ("&hashkey","&inds_keep"))
    );
  by &inds_keep &hashkey;
  var _character_;
run;

%if %index(&libds,-)>0 and %scan(&libds,2,-)=FC %then %do;
  /* this is a format catalog - cannot query cols directly */
  %let vlist="TYPE","FMTNAME","FMTROW","START","END","LABEL","MIN","MAX"
    ,"DEFAULT","LENGTH","FUZZ","PREFIX","MULT","FILL","NOEDIT","SEXCL"
    ,"EEXCL","HLO","DECSEP","DIG3SEP","DATATYPE","LANGUAGE";
%end;
%else %let vlist=%mf_getvarlist(&libds,dlm=%str(,),quote=DOUBLE);

data &ds4;
  length &inds_keep $41 tgtvar_nm $32 _label_ $256;
  if _n_=1 then call missing(_label_);
  drop _label_;
  set &ds2 &ds3 indsname=&inds_auto;

  tgtvar_nm=upcase(tgtvar_nm);
  if tgtvar_nm in (%upcase(&vlist));

  if upcase(&inds_auto)="&ds2" then tgtvar_type='N';
  else if upcase(&inds_auto)="&ds3" then tgtvar_type='C';
  else do;
    putlog 'ERR' +(-1) "OR: unidentified vartype input!" &inds_auto;
    call symputx('syscc',98);
  end;

  if &inds_keep="&appds" then move_type='A';
  else if &inds_keep="&delds" then move_type='D';
  else if &inds_keep="&modds" then move_type='M';
  else if &inds_keep="&origds" then move_type='O';
  else do;
    putlog 'ERR' +(-1) "OR: unidentified movetype input!" &inds_keep;
    call symputx('syscc',99);
  end;
  tgtvar_nm=upcase(tgtvar_nm);
  if tgtvar_nm in (%mf_getquotedstr(&key)) then is_pk=1;
  else is_pk=0;
  drop &inds_keep;
run;

%if "&loadref"="0" %then %let loadref=%sysfunc(uuidgen());
%if &processed_dttm=0 %then %let processed_dttm=%sysfunc(datetime());
%let libds=%upcase(&libds);

/* join orig vals for modified & deleted */
proc sql;
create table &outds as
  select "&loadref" as load_ref length=36
    ,&processed_dttm as processed_dttm format=E8601DT26.6
    ,"%scan(&libds,1,.)" as libref length=8
    ,"%scan(&libds,2,.)" as dsn length=32
    ,b.key_hash length=32
    ,b.move_type length=1
    ,b.tgtvar_nm length=32
    ,b.is_pk
    ,case when b.move_type ne 'M' then -1
      when a.newval_num=b.newval_num and a.newval_char=b.newval_char then 0
      else 1
      end as is_diff
    ,b.tgtvar_type length=1
    ,case when b.move_type='D' then b.newval_num
      else a.newval_num
      end as oldval_num format=best32.
    ,case when b.move_type='D' then .
      else b.newval_num
      end as newval_num format=best32.
    ,case when b.move_type='D' then b.newval_char
      else a.newval_char
      end as oldval_char length=32765
    ,case when b.move_type='D' then ''
      else b.newval_char
      end as newval_char length=32765
  from &ds4(where=(move_type='O')) as a
  right join &ds4(where=(move_type ne 'O')) as b
  on a.tgtvar_nm=b.tgtvar_nm
  and a.key_hash=b.key_hash
  order by move_type, key_hash,is_pk desc, tgtvar_nm;

%if &mdebug=0 %then %do;
  proc sql;
  drop table &ds1, &ds2, &ds3, &ds4;
%end;

%mend mp_storediffs;
/** @endcond */