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
  way out, so its own text does not leak into whatever the caller prints next.
  A caller that has its own titles and footnotes must set them again after the
  call: SAS offers no way to read the title or footnote text back (GETOPTION
  does not report them), so they cannot be saved and restored the way the page
  orientation is.

  The page numbers are written with the `(*ESC*)` inline-function prefix
  rather than with an escape character, so the report does not depend on the
  caller having run `ods escapechar=`.

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
    @li PAGEOF - "Page n of m"
    @li NO - no page number
    The numbers come from the ODS inline functions `{thispage}` and
    `{lastpage}`, written behind the `(*ESC*)` prefix so no ODS ESCAPECHAR has
    to be set. SAS documents `{lastpage}` as preproduction, and warns that
    images and URL links can be dropped from a title or footnote that uses it -
    this macro prints a table only, so the total is safe here, but that is why
    it is not the default.

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

%local obsopt foot pagetxt odsopts prev_orient;

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

/* the caller's footnote keeps its own text; numbering is appended to it.
  (*ESC*) is used rather than an escape character so the inline functions work
  without the caller having set ods escapechar. */
%if &pagenum=PAGE %then %let pagetxt=Page (*ESC*){thispage};
%else %if &pagenum=PAGEOF %then
  %let pagetxt=Page (*ESC*){thispage} of (*ESC*){lastpage};

%let foot=&footnote;
%if %length(&pagetxt)>0 %then %do;
  %if %length(&foot)>0 %then %let foot=&foot &pagetxt;
  %else %let foot=&pagetxt;
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
