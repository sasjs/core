/**
  @file
  @brief Export format definitions
  @details Formats are exported from the first (if any) catalog entry in the
  FMTSEARCH path.

  Formats are taken from the library / dataset reference and / or a static
  format list.

  Example usage:

      %mp_getformats(lib=sashelp,ds=prdsale,outsummary=work.dictable)

  @param [in] lib= (0) The libref for which to return formats.
  @todo Enable exporting of formats for an entire library
  @param [in] ds= (0) The dataset from which to obtain format definitions
  @param [in] fmtlist= (0) A list of additional format names
  @param [out] outsummary= (work.mp_getformats_summary) Output dataset
    containing summary definitions - structure taken from dictionary.formats as
    follows:

  |libname:$8.|memname:$32.|path:$1024.|objname:$32.|fmtname:$32.|fmttype:$1.|source:$1.|minw:best.|mind:best.|maxw:best.|maxd:best.|defw:best.|defd:best.|
  |---|---|---|---|---|---|---|---|---|---|---|---|---|
  | | | | |$|F|B|1|0|32767|0|1|0|
  | | | | |$|I|B|1|0|32767|0|1|0|
  |` `|` `|/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWIANYDT|$ANYDTIF|I|U|1|0|60|0|19|0|
  | | |/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWFASCII|$ASCII|F|U|1|0|32767|0|1|0|
  | | |/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWIASCII|$ASCII|I|U|1|0|32767|0|1|0|
  | | |/opt/sas/sas9/SASHome/SASFoundation/9.4/sasexe|UWFBASE6|$BASE64X|F|U|1|0|32767|0|1|0|


  @param [out] outdetail= (0) Provide an output dataset in which to export all
    the custom format definitions (from proc format CNTLOUT).  Definitions:
https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/viewer.htm#a002473477.htm
    Sample data:

  |FMTNAME:$32.|START:$16.|END:$16.|LABEL:$256.|MIN:best.|MAX:best.|DEFAULT:best.|LENGTH:best.|FUZZ:best.|PREFIX:$2.|MULT:best.|FILL:$1.|NOEDIT:best.|TYPE:$1.|SEXCL:$1.|EEXCL:$1.|HLO:$13.|DECSEP:$1.|DIG3SEP:$1.|DATATYPE:$8.|LANGUAGE:$8.|
  |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
  |`WHICHPATH `|`0 `|`0 `|`path1 `|`1 `|`40 `|`28 `|`28 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`N `|` `|` `|` `|` `|` `|
  |`WHICHPATH `|`**OTHER** `|`**OTHER** `|`big fat problem if not path1 `|`1 `|`40 `|`28 `|`28 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`N `|`O `|` `|` `|` `|` `|

  <h4> SAS Macros </h4>
  @li mddl_sas_cntlout.sas
  @li mf_dedup.sas
  @li mf_getfmtlist.sas
  @li mf_getfmtname.sas
  @li mf_getquotedstr.sas
  @li mf_getuniquename.sas


  <h4> Related Macros </h4>
  @li mp_applyformats.sas
  @li mp_getformats.test.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getformats(lib=0
  ,ds=0
  ,fmtlist=0
  ,outsummary=work.mp_getformats_summary
  ,outdetail=0
);

%local i fmt allfmts tempds fmtcnt;

%if "&fmtlist" ne "0" %then %do i=1 %to %sysfunc(countw(&fmtlist,,%str( )));
  /* ensure format list contains format _name_ only */
  %let fmt=%scan(&fmtlist,&i,%str( ));
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

/* create summary table */
%if %index(&outsummary,.)=0 %then %let outsummary=WORK.&outsummary;
proc sql;
create table &outsummary as
  select * from dictionary.formats
  where fmtname in (%mf_getquotedstr(&allfmts,quote=D))
    and fmttype='F';

%if "&outdetail" ne "0" %then %do;
  /* ensure base table always exists */
  %mddl_sas_cntlout(libds=&outdetail)
  /* grab the location of each format */
  %let fmtcnt=0;
  data _null_;
    set &outsummary;
    if not missing(libname);
    x+1;
    call symputx(cats('fmtloc',x),cats(libname,'.',memname),'l');
    call symputx(cats('fmtname',x),fmtname,'l');
    call symputx('fmtcnt',x,'l');
  run;
  /* export each format and append to the output table */
  %let tempds=%mf_getuniquename(prefix=mp_getformats);
  %do i=1 %to &fmtcnt;
    proc format library=&&fmtloc&i CNTLOUT=&tempds;
      select &&fmtname&i;
    run;
    data &tempds;
      if 0 then set &outdetail;
      set &tempds;
    run;
    proc append base=&outdetail data=&tempds ;
    run;
  %end;
%end;

%mend mp_getformats;