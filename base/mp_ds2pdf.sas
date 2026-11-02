/**
  @file
  @brief Create a PDF report from a dataset using ODS
  @details Renders a dataset as a paginated PDF with ODS PDF, so the output
  carries real typesetting - proportional fonts, repeated column headers on
  every page, titles, footnotes and page numbers - rather than a picture of a
  grid. Values are printed through PROC PRINT, so SAS formats and labels are
  applied to what the reader sees.

  This is the server-side half of a download pair: send the result with
  `mp_streamfile` using `contenttype=PDF`.

  Usage:

      filename mypdf temp;
      %mp_ds2pdf(sashelp.class, outref=mypdf
        ,title=Class listing
        ,footnote=Class table - generated &sysdate9);

      %mp_streamfile(contenttype=PDF,inref=mypdf,outname=class.pdf)

  Handling of the ODS session: the macro opens its own PDF destination, sets
  titles and footnotes for the duration of the report and clears them on the
  way out, so it can be called from a program that has its own titles. The
  page orientation option is saved and restored around the report.

  @param [in] ds The dataset to print. A name without a libref is read from
    WORK.
  @param [out] outref= (pdfout) Fileref to contain the PDF. Assigned as a TEMP
    file if it is not already allocated.
  @param [in] title= Optional report title, printed on every page.
  @param [in] footnote= Optional footnote text. The page number is appended to
    it (see `pagenum=`), so pass the provenance here - dataset, filter, user,
    timestamp - and leave the numbering to the macro.
  @param [in] by= Optional space separated BY variables. Each BY group starts a
    new page, so the data must already be sorted by those variables.
  @param [in] maxobs= (0) Maximum number of observations to print. 0 prints
    every observation. Use it to cap very large tables, and say so in
    `footnote=` when a cap has been applied.
  @param [in] options= Additional options for the ODS PDF statement, for
    example `fontsize=9`. The statement always carries `notoc`.
  @param [in] style= Optional ODS style. Left to the site default when blank.
  @param [in] orientation= (LANDSCAPE) Page orientation, one of LANDSCAPE or
    PORTRAIT. This is a SAS system option rather than an ODS PDF attribute, so
    the previous setting is restored on the way out.
  @param [in] pagenum= (PAGE) Numbering appended to the footnote. Supported
    values:
    @li PAGE - "Page n"
    @li NO - no page number
    A total ("Page n of m") is deliberately not offered: ODS PDF exposes the
    current page but not the last one, and the page objects in the file are not
    reliably countable without parsing it, so a total would mean rendering the
    report twice and then guessing.

  @return The PDF is written to `outref`. No dataset is created.

  <h4> SAS Macros </h4>
  @li mp_abort.sas

  @author 4GL Apps Ltd
  @copyright 4GL Apps Ltd.  This code may only be used within Data Controller
    and may not be re-distributed or re-sold without the express permission of
    4GL Apps Ltd.

**/

%macro mp_ds2pdf(
  ds
  ,outref=pdfout
  ,title=
  ,footnote=
  ,by=
  ,maxobs=0
  ,options=
  ,style=
  ,orientation=LANDSCAPE
  ,pagenum=PAGE
)/*/STORE SOURCE*/;

%local obsopt foot odsopts prev_orient;

%if %index(&ds,.)=0 %then %let ds=WORK.&ds;
%let ds=%upcase(&ds);
%let pagenum=%upcase(&pagenum);
%let orientation=%upcase(&orientation);

%if %sysfunc(exist(&ds))=0 %then %do;
  %mp_abort(
    msg=Dataset &ds does not exist
    ,mac=&sysmacroname
  )
%end;

/* the fileref is only assigned when the caller has not done so */
%if %sysfunc(fileref(&outref)) > 0 %then %do;
  filename &outref temp;
%end;

%let obsopt=;
%if %eval(&maxobs)>0 %then %let obsopt=(obs=&maxobs);

/* the caller's footnote keeps its own text; numbering is appended to it */
%let foot=&footnote;
%if &pagenum=PAGE %then %do;
  %if %length(&foot) ne 0 %then %let foot=&foot ^{thispage};
  %else %let foot=Page ^{thispage};
%end;

%let odsopts=notoc;
%if %length(&options)>0 %then %let odsopts=&odsopts &options;

%let prev_orient=%sysfunc(getoption(orientation));
options orientation=&orientation;

ods pdf file=&outref &odsopts
  %if %length(&style)>0 %then style=&style;;

/* each of these needs its own %do block: a bare "%then statement;" swallows
  the semicolon as part of the %if, so the statements after it are read as a
  continuation of the same statement */
%if %length(&title)>0 %then %do;
  title "&title";
%end;
%if %length(&foot)>0 %then %do;
  footnote "&foot";
%end;

proc print data=&ds&obsopt noobs;
  %if %length(&by)>0 %then %do;
    by &by;
  %end;
run;

ods pdf close;
title;
footnote;
options orientation=&prev_orient;

%mend mp_ds2pdf;
