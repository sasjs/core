/**
  @file mp_streamfile.sas
  @brief Streams a file to _webout according to content type
  @details Will set headers using appropriate functions (SAS 9 vs Viya) and send
  content as a binary stream.

  Usage:

      filename mc url "https://raw.githubusercontent.com/macropeople/macrocore/master/mc_all.sas";
      %inc mc;

      %mp_streamfile(contenttype=csv,inloc=/some/where.txt,outname=myfile.txt)

  <h4> Dependencies </h4>
  @li mf_getplatform.sas
  @li mp_binarycopy.sas

  @param contenttype= Either TEXT, ZIP, CSV, EXCEL (default TEXT)
  @param inloc= /path/to/file.ext to be sent
  @param outname= the name of the file, as downloaded by the browser

  @author Allan Bowe
  @source https://github.com/macropeople/macrocore

**/

%macro mp_streamfile(
  contenttype=TEXT
  ,inloc=
  ,outname=
)/*/STORE SOURCE*/;

%let contentype=%upcase(&contenttype);
%local platform; %let platform=%mf_getplatform();

%if &contentype=ZIP %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/zip');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.zip'
      contenttype='application/zip' 
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=EXCEL %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/vnd.ms-excel');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.xls'
      contenttype='application/vnd.ms-excel' 
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=TEXT %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/text');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.txt'
      contenttype='application/text'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=CSV %then %do;
  %if &platform=SASMETA %then %do;
    data _null_;
      rc=stpsrv_header('Content-type','application/csv');
      rc=stpsrv_header('Content-disposition',"attachment; filename=&outname");
    run;
  %end;
  %else %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name='_webout.txt'
      contenttype='application/csv'
      contentdisp="attachment; filename=&outname";
  %end;
%end;
%else %if &contentype=HTML %then %do;
  %if &platform=SASVIYA %then %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name="_webout.json"
      contenttype="text/html"; 
  %end;
%end;
%else %do;
  %put %str(ERR)OR: Content Type &contenttype NOT SUPPORTED by &sysmacroname!;
  %return;
%end;

%mp_binarycopy(inloc="&inloc",outref=_webout)

%mend;