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
      @li Respect PKs
      @li Respect NOT NULLs
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

  @param [in] libds The empty table in which to create data
  @param [out] obs= (500) The number of records to create.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_getvarlen.sas
  @li mf_nobs.sas
  @li mp_getcols.sas
  @li mp_getpk.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_makedata(libds
  ,obs=500
)/*/STORE SOURCE*/;

%local ds1 c1 n1 i col charvars numvars;

%if %mf_nobs(&libds)>0 %then %do;
  %put &sysmacroname: &libds has data, it will not be recreated;
  %return;
%end;

%local ds1 c1 n1;
%let ds1=%mf_getuniquename(prefix=mp_makedata);
%let c1=%mf_getuniquename(prefix=mp_makedatacol);
%let n1=%mf_getuniquename(prefix=mp_makedatacol);
data &ds1;
  if 0 then set &libds;
  do _n_=1 to &obs;
    &c1=repeat(uuidgen(),10);
    &n1=ranuni(1)*5000000;
    drop &c1 &n1;
    %let charvars=%mf_getvarlist(&libds,typefilter=C);
    %do i=1 %to %sysfunc(countw(&charvars));
      %let col=%scan(&charvars,&i);
      &col=subpad(&c1,1,%mf_getvarlen(&libds,&col));
    %end;

    %let numvars=%mf_getvarlist(&libds,typefilter=N);
    %do i=1 %to %sysfunc(countw(&numvars));
      %let col=%scan(&numvars,&i);
      &col=&n1;
    %end;
    output;
  end;
run;

proc append base=&libds data=&ds1;
run;

proc sql;
drop table &ds1;

%mend mp_makedata;