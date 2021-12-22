/**
  @file
  @brief Create sample data based on the structure of an empty table
  @details Many SAS projects involve sensitive datasets.  One way to _ensure_
    the data is anonymised, is never to receive it in the first place!  Often
    consultants are provided with empty tables, and expected to create complex
    ETL flows.

    This macro can help by taking an empty table, and populating it with data
    according to the variable types and formats.

    TODO:
      @li Consider dates, datetimes, times, integers etc

  Usage:

      proc sql;
      create table work.example(
        TX_FROM float format=datetime19.,
        DD_TYPE char(16),
        DD_SOURCE char(2048),
        DD_SHORTDESC char(256),
        constraint pk primary key(tx_from, dd_type,dd_source),
        constraint nnn not null(DD_SHORTDESC)
      );
      %mp_makedata(work.example)

  @param [in] libds The empty table (libref.dataset) in which to create data
  @param [out] obs= (500) The maximum number of records to create.  The table
    is sorted with nodup on the primary key, so the actual number of records may
    be lower than this.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_getvarlen.sas
  @li mf_islibds.sas
  @li mf_nobs.sas
  @li mp_getcols.sas
  @li mp_getpk.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_makedata(libds
  ,obs=500
  ,seed=1
)/*/STORE SOURCE*/;

%local ds1 ds2 lib ds pk_fields i col charvars numvars ispk;

%if %mf_islibds(&libds)=0 %then %do;
  %put &sysmacroname: Invalid libds (&libds) - should be library.dataset format;
  %return;
%end;
%else %if %mf_nobs(&libds)>0 %then %do;
  %put &sysmacroname: &libds has data, it will not be recreated;
  %return;
%end;

/* set up temporary vars */
%let ds1=%mf_getuniquename(prefix=mp_makedatads1);
%let ds2=%mf_getuniquename(prefix=mp_makedatads2);
%let lib=%scan(&libds,1,.);
%let ds=%scan(&libds,2,.);

/* grab the primary key vars */
%mp_getpk(&lib,ds=&ds,outds=&ds1)

proc sql noprint;
select pk_fields into: pk_fields from &ds1;

data &ds2;
  if 0 then set &libds;
  do _n_=1 to &obs;
    %let charvars=%mf_getvarlist(&libds,typefilter=C);
    %if &charvars ^= %then %do i=1 %to %sysfunc(countw(&charvars));
      %let col=%scan(&charvars,&i);
      /* create random value based on observation number and colum length */
      &col=substr(put(md5(_n_),$hex32.),1,%mf_getvarlen(&libds,&col));
    %end;

    %let numvars=%mf_getvarlist(&libds,typefilter=N);
    %if &numvars ^= %then %do i=1 %to %sysfunc(countw(&numvars));
      %let col=%scan(&numvars,&i);
      &col=_n_;
    %end;
    output;
  end;
run;
proc sort data=&ds2 nodupkey;
  by &pk_fields;
run;

proc append base=&libds data=&ds2;
run;

proc sql;
drop table &ds1, &ds2;

%mend mp_makedata;