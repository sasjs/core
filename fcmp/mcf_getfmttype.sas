/**
  @file
  @brief Returns the type of the format
  @details
  Returns the type, eg DATE / DATETIME / TIME (based on hard-coded lookup)
  else CHAR / NUM.

  This macro may be extended in the future to support custom formats - this
  would necessitate a call to `dosubl()` for running a proc format with cntlout.

  The function itself takes the following (positional) parameters:

  | PARAMETER | DESCRIPTION |
  |---|---|
  |fmtnm| Format name to be tested.  Can be with or without the w.d extension.|

  Usage:

      %mcf_getfmttype(wrap=YES, insert_cmplib=YES)

      data _null_;
        fmt1=mcf_getfmttype('DATE9.');
        fmt2=mcf_getfmttype('DATETIME');
        put (fmt:)(=);
      run;
      %put fmt3=%sysfunc(mcf_getfmttype(TIME9.));

  Returns:

  > fmt1=DATE fmt2=DATETIME
  > fmt3=TIME

  @param [out] wrap= (NO) Choose YES to add the proc fcmp wrapper.
  @param [out] lib= (work) The output library in which to create the catalog.
  @param [out] cat= (sasjs) The output catalog in which to create the package.
  @param [out] pkg= (utils) The output package in which to create the function.
    Uses a 3 part format:  libref.catalog.package
  @param [out] insert_cmplib= DEPRECATED - The CMPLIB option is checked and
    values inserted only if needed.

  <h4> SAS Macros </h4>
  @li mcf_init.sas

  <h4> Related Programs </h4>
  @li mcf_getfmttype.test.sas
  @li mp_init.sas

  @todo "Custom Format Lookups" To enable site-specific formats, make
  use of a set of SASJS_FMTLIST_(DATATYPE) global variables.

**/

%macro mcf_getfmttype(wrap=NO
  ,insert_cmplib=DEPRECATED
  ,lib=WORK
  ,cat=SASJS
  ,pkg=UTILS
)/*/STORE SOURCE*/;
%local i var cmpval found;

%if %mcf_init(mcf_getfmttype)=1 %then %return;

%if &wrap=YES  %then %do;
  proc fcmp outlib=&lib..&cat..&pkg;
%end;

function mcf_getfmttype(fmtnm $) $8;
  if substr(fmtnm,1,1)='$' then return('CHAR');
  else do;
    /* extract NAME */
    length fmt $32;
    fmt=scan(fmtnm,1,'.');
    do while (
      substr(fmt,length(fmt),1) in ('1','2','3','4','5','6','7','8','9','0')
      );
      if length(fmt)=1 then fmt='W';
      else fmt=substr(fmt,1,length(fmt)-1);
    end;

    /* apply lookups */
    if cats(fmt) in ('DATETIME','B8601DN','B8601DN','B8601DT','B8601DT'
      ,'B8601DZ','B8601DZ','DATEAMPM','DTDATE','DTMONYY','DTWKDATX','DTYEAR'
      ,'DTYYQC','E8601DN','E8601DN','E8601DT','E8601DT','E8601DZ','E8601DZ')
      then return('DATETIME');
    else if fmt in ('DATE','YYMMDD','B8601DA','B8601DA','DAY','DDMMYY'
      ,'DDMMYYB','DDMMYYC','DDMMYYD','DDMMYYN','DDMMYYP','DDMMYYS','DDMMYYx'
      ,'DOWNAME','E8601DA','E8601DA','JULDAY','JULIAN','MMDDYY','MMDDYYB'
      ,'MMDDYYC','MMDDYYD','MMDDYYN','MMDDYYP','MMDDYYS','MMDDYYx','MMYY'
      ,'MMYYC','MMYYD','MMYYN','MMYYP','MMYYS','MMYYx','MONNAME','MONTH'
      ,'MONYY','PDJULG','PDJULI','QTR','QTRR','WEEKDATE','WEEKDATX','WEEKDAY'
      ,'WEEKU','WEEKV','WEEKW','WORDDATE','WORDDATX','YEAR','YYMM','YYMMC'
      ,'YYMMD','YYMMDDB','YYMMDDC','YYMMDDD','YYMMDDN','YYMMDDP','YYMMDDS'
      ,'YYMMDDx','YYMMN','YYMMP','YYMMS','YYMMx','YYMON','YYQ','YYQC','YYQD'
      ,'YYQN','YYQP','YYQR','YYQRC','YYQRD','YYQRN','YYQRP','YYQRS','YYQRx'
      ,'YYQS','YYQx','YYQZ') then return('DATE');
    else if fmt in ('TIME','B8601LZ','B8601LZ','B8601TM','B8601TM','B8601TZ'
      ,'B8601TZ','E8601LZ','E8601LZ','E8601TM','E8601TM','E8601TZ','E8601TZ'
      ,'HHMM','HOUR','MMSS','TIMEAMPM','TOD') then return('TIME');
    else return('NUM');
  end;
endsub;

%if &wrap=YES %then %do;
  quit;
%end;

/* insert the CMPLIB if not already there */
%let cmpval=%sysfunc(getoption(cmplib));
%let found=0;
%do i=1 %to %sysfunc(countw(&cmpval,%str( %(%))));
  %let var=%scan(&cmpval,&i,%str( %(%)));
  %if &var=&lib..&cat %then %let found=1;
%end;
%if &found=0 %then %do;
  options insert=(CMPLIB=(&lib..&cat));
%end;

%mend mcf_getfmttype;