/**
  @file
  @brief Fixes embedded cr / lf / crlf in CSV
  @details CSVs will sometimes contain lf or crlf within quotes (eg when
  saved by excel).  When the termstr is ALSO lf or crlf that can be tricky
  to process using SAS defaults.
  This macro converts any csv to follow the convention of a windows excel file,
  applying CRLF line endings and converting embedded cr and crlf to lf.

  Usage:

      fileref mycsv "/path/your/csv";
      %mp_cleancsv(in=mycsv,out=/path/new.csv)

  @param [in] in= (NOTPROVIDED)
    Provide path or fileref to input csv. If a period is
    found, it is assumed to be a file.
  @param [in] out= (NOTPROVIDED) Output path or fileref to output csv.
    If a period is found, it is assumed to be a file.
  @param [in] qchar= ('22'x) Quote char - hex code 22 is the double quote.

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mp_cleancsv(in=NOTPROVIDED,out=NOTPROVIDED,qchar='22'x);
%if "&in"="NOTPROVIDED" or "&out"="NOTPROVIDED" %then %do;
  %put %str(ERR)OR: Please provide valid input (&in) & output (&out) locations;
  %return;
%end;

/* presence of a period(.) indicates a physical location */
%if %index(&in,.) %then %let in="&in";
%if %index(&out,.) %then %let out="&out";

/**
  * convert all cr and crlf within quotes to lf
  * convert all other cr or lf to crlf
  */
  data _null_;
    infile &in recfm=n ;
    file &out recfm=n;
    retain isq iscrlf 0 qchar &qchar;
    input inchar $char1. ;
    if inchar=qchar then isq = mod(isq+1,2);
    if isq then do;
      /* inside a quote change cr and crlf to lf */
      if inchar='0D'x then do;
        put '0A'x;
        input inchar $char1.;
        if inchar ne '0A'x then do;
          put inchar $char1.;
          if inchar=qchar then isq = mod(isq+1,2);
        end;
      end;
      else put inchar $char1.;
    end;
    else do;
      /* outside a quote, change cr and lf to crlf */
      if inchar='0D'x then do;
        crblank:
        put '0D0A'x;
        input inchar $char1.;
        if inchar='0D'x then do;
          /* multiple CR indicates CR formatted file with blank lines */
          goto crblank;
        end;
        else if inchar ne '0A'x then do;
          put inchar $char1.;
          if inchar=qchar then isq = mod(isq+1,2);
        end;
      end;
      else if inchar='0A'x then put '0D0A'x;
      else put inchar $char1.;
    end;
  run;
%mend mp_cleancsv;
/** @endcond */