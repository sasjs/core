/**
  @file
  @brief Returns the SAS format names that carry a date, datetime or time value

  @details Prints a quoted, comma separated list of format NAMES, for use in
    open code or in generated code:

        if upcase(fmt) in (%mf_dttmfmts(DATE)) then fmttype='DATE';
        else if upcase(fmt) in (%mf_dttmfmts(DATETIME)) then fmttype='DATETIME';
        else if upcase(fmt) in (%mf_dttmfmts(TIME)) then fmttype='TIME';
        else fmttype='NUM';

    The names carry no width or decimal suffix, so strip that first (eg DATE9.
    becomes DATE).  This macro is the single source of truth for the lists -
    mcf_getfmttype.sas builds its FCMP lookups from it.

  @param [in] type DATE / DATETIME / TIME (case insensitive)

  <h4> SAS Macros </h4>
  @li mp_abort.sas

  <h4> Related Macros </h4>
  @li mcf_getfmttype.sas

  @version 9.4
  @author Allan Bowe
**/

%macro mf_dttmfmts(type);
%local type found;
%let type=%upcase(&type);
%let found=0;
/* so an empty type reaches the abort below */
%if %length(&type)=0 %then %let type=INVALID;

%if &type=DATE %then %do;
  %let found=1;
  'DATE','YYMMDD','B8601DA','DAY','DDMMYY','DDMMYYB','DDMMYYC','DDMMYYD',
  'DDMMYYN','DDMMYYP','DDMMYYS','DDMMYYx','DOWNAME','E8601DA','JULDAY',
  'JULIAN','MMDDYY','MMDDYYB','MMDDYYC','MMDDYYD','MMDDYYN','MMDDYYP',
  'MMDDYYS','MMDDYYx','MMYY','MMYYC','MMYYD','MMYYN','MMYYP','MMYYS','MMYYx',
  'MONNAME','MONTH','MONYY','PDJULG','PDJULI','QTR','QTRR','WEEKDATE',
  'WEEKDATX','WEEKDAY','WEEKU','WEEKV','WEEKW','WORDDATE','WORDDATX','YEAR',
  'YYMM','YYMMC','YYMMD','YYMMDDB','YYMMDDC','YYMMDDD','YYMMDDN','YYMMDDP',
  'YYMMDDS','YYMMDDx','YYMMN','YYMMP','YYMMS','YYMMx','YYMON','YYQ','YYQC',
  'YYQD','YYQN','YYQP','YYQR','YYQRC','YYQRD','YYQRN','YYQRP','YYQRS',
  'YYQRx','YYQS','YYQx','YYQZ','NLDATE'
%end;
%else %if &type=DATETIME %then %do;
  %let found=1;
  'DATETIME','B8601DN','B8601DT','B8601DZ','DATEAMPM','DTDATE','DTMONYY',
  'DTWKDATX','DTYEAR','DTYYQC','E8601DN','E8601DT','E8601DZ','NLDATM'
%end;
%else %if &type=TIME %then %do;
  %let found=1;
  'TIME','B8601LZ','B8601TM','B8601TZ','E8601LZ','E8601TM','E8601TZ','HHMM',
  'HOUR','MMSS','TIMEAMPM','TOD'
%end;

%mp_abort(iftrue=(&found=0)
  ,mac=&sysmacroname
  ,msg=%str(type must be DATE, DATETIME or TIME - got: &type)
)

%mend mf_dttmfmts;
