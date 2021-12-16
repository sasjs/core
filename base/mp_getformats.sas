/**
  @file
  @brief Export format definitions
  @details Formats are exported from the first (if any) catalog entry in the
  FMTSEARCH path.

  Formats are taken from the library / dataset reference and / or a static
  format list.

  Example usage:

      %mp_getformats(lib=sashelp,ds=prdsale,outds=work.prdfmts)

  @param [in] lib= (0) The libref for which to return formats.
  @todo Enable exporting of formats for an entire library
  @param [in] ds= (0) The dataset from which to obtain format definitions
  @param [in] fmtstring= (0) A list of additional format names
  @param [out] outsummary= (work.mp_getformats_summary) Output dataset
    containing summary definitions - structure taken from dictionary.formats as
    follows:
|libname:$8.|memname:$32.|path:$1024.|objname:$32.|fmtname:$32.|fmttype:$1.|source:$1.|minw:best.|mind:best.|maxw:best.|maxd:best.|d
efw:best.|defd:best.|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|||||$|F|B|1|0|32767|0|1|0|
|||||$|I|B|1|0|32767|0|1|0|
|||/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWIANYDT|$ANYDTIF|I|U|1|0|60|0|19|0|
|||/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWFASCII|$ASCII|F|U|1|0|32767|0|1|0|
|||/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWIASCII|$ASCII|I|U|1|0|32767|0|1|0|
|||/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWFBASE6|$BASE64X|F|U|1|0|32767|0|1|0|
|||/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWIBASE6|$BASE64X|I|U|1|0|32767|0|1|0|
|||/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWFBIDI|$BIDI|F|U|1|0|32767|0|1|0|
|||||$BINARY|F|B|1|0|32767|0|8|0|
|||||$BINARY|I|B|1|0|32767|0|8|0|

  @param [out] outdetail= (work.mp_getformats_detail) The output dataset to
    contain the format definitions (from proc format CNTLOUT).  Sample data:

  |NAME $|LENGTH 8|VARNUM 8|LABEL $|FORMAT $49|TYPE $1 |DDTYPE $|
  |---|---|---|---|---|---|---|
  |AIR|8|2|international airline travel (thousands)|8.|N|NUMERIC|
  |DATE|8|1|DATE|MONYY.|N|DATE|
  |REGION|3|3|REGION|$3.|C|CHARACTER|

  <h4> SAS Macros </h4>
  @li mf_dedup.sas
  @li mf_getfmtlist.sas
  @li mf_getfmtname.sas
  @li mf_getquotedstr.sas


  <h4> Related Macros </h4>
  @li mp_getformats.test.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getformats(lib=0
  ,ds=0
  ,fmtstring=0
  ,outsummary=work.mp_getformats_summary
  ,outdetail=work.mp_getformats_detail
);

%local i fmt allfmts;
%if "&fmtstring" ne "0" %then %do i=1 %to %sysfunc(countw(&fmtstring,,%str( )));
  /* ensure format list contains format _name_ only */
  %let fmt=%scan(&fmtstring,&i,%str( ));
  %let fmt=%mf_getfmtname(&fmt);
  %let allfmts=&allfmts &fmt;
%end;

%if &ds=0 and &lib ne 0 %then %do;
  /* grab formats from library */
  /* to do */
%end;
%else %if &ds ne 0 and &lib ne 0 %then %do;
  /* grab formats from dataset */
  %let allfmts=%mf_getfmtlist(&lib..&ds) &allfmts;
%end;

/* ensure list is unique */
%let allfmts=%mf_dedup(%upcase(&allfmts));

/* now we have the formats, lets figure out the search path */
proc sql;
create table &outsummary as
  select * from dictionary.formats
  where fmtname in (%mf_getquotedstr(&allfmts,quote=D))



%mend mp_getformats;