/**
  @file
  @brief Streams a file to _webout according to content type
  @details Will set headers using appropriate functions (SAS 9 vs Viya) and send
  content as a binary stream.

  Usage:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mp_streamfile(contenttype=csv,inloc=/some/where.txt,outname=myfile.txt)

  @param [in] contenttype= (TEXTS) Either TEXT, ZIP, CSV, EXCEL
  @param [in] inloc= /path/to/file.ext to be sent
  @param [in] inref= fileref of file to be sent (if provided, overrides `inloc`)
  @param [in] iftrue= (1=1) Provide a condition under which to execute.
  @param [out] outname= the name of the file, as downloaded by the browser
  @param [out] outref= (_webout) The destination where the file should be
    streamed.

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mp_binarycopy.sas

  @author Allan Bowe

**/

%macro mp_streamfile(
  contenttype=TEXT
  ,inloc=
  ,inref=0
  ,iftrue=%str(1=1)
  ,outname=
  ,outref=_webout
)/*/STORE SOURCE*/;

%if not(%eval(%unquote(&iftrue))) %then %return;

%let contentype=%upcase(&contenttype);
%let outref=%upcase(&outref);
%local platform; %let platform=%mf_getplatform();

/**
  * check engine type to avoid the below err message:
  * > Function is only valid for filerefs using the CACHE access method.
  */
%local streamweb;
%let streamweb=0;
data _null_;
  set sashelp.vextfl(where=(upcase(fileref)="&outref"));
  if xengine='STREAM' then call symputx('streamweb',1,'l');
run;

%if &contentype=CSV %then %do;
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/csv');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.txt'
      contenttype='application/csv'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=EXCEL %then %do;
  /* suitable for XLS format */
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/vnd.ms-excel');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.xls'
      contenttype='application/vnd.ms-excel'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=GIF or &contentype=JPEG or &contentype=PNG %then %do;
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type',"image/%lowcase(&contenttype)");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI"
      contenttype="image/%lowcase(&contenttype)";
  %end;
%end;
%else %if &contentype=HTML %then %do;
  %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI" name="_webout.json"
      contenttype="text/html";
  %end;
%end;
%else %if &contentype=TEXT %then %do;
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/text');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.txt'
      contenttype='application/text'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=WOFF or &contentype=WOFF2 or &contentype=TTF %then %do;
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type',"font/%lowcase(&contenttype)");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI"
      contenttype="font/%lowcase(&contenttype)";
  %end;
%end;
%else %if &contentype=XLSX %then %do;
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.xls'
      contenttype=
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=ZIP %then %do;
  %if (&platform=SASMETA and &streamweb=1) or &platform=SASJS %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/zip');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename &outref filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.zip'
      contenttype='application/zip'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %do;
  %put %str(ERR)OR: Content Type &contenttype NOT SUPPORTED by &sysmacroname!;
%end;

%if &inref ne 0 %then %do;
  %mp_binarycopy(inref=&inref,outref=&outref)
%end;
%else %do;
  %mp_binarycopy(inloc="&inloc",outref=&outref)
%end;

%mend mp_streamfile;
