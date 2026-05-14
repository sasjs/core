/**
  @file
  @brief Appends a text file to a SASjs Stored Program, Viya SAS program, or
    SAS 9 Stored Process
  @details Extracts the source code from a SASjs Stored Program, Viya SAS
  program (file in SAS Drive), or SAS 9 Stored Process, appends the contents
  of a provided text file, then deletes and recreates the target item with the
  combined content.

  This is useful for dynamically modifying deployed programs, for example to
  add test-specific configuration or runtime settings.

  Usage:

      %* compile macros ;
      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* write some content to append;
      filename append temp;
      data _null_;
        file append;
        put "libname mylib '/some/path';";
      run;

      %* append to existing program;
      %mx_append2pgm(/Public/app/common/settings, inref=append)

  @param [in] loc The full path to the Viya SAS program, SAS 9 Stored Process,
    or SASjs Stored Program in Drive or Metadata, WITHOUT the .sas extension
    (SASjs only)
  @param [in] inref= (0) Fileref pointing to the content to be appended to the
    target program.
  @param [in] mdebug= (0) Set to 1 to show debug messages in the log

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mm_createstp.sas
  @li mm_deletestp.sas
  @li mm_getstpcode.sas
  @li ms_createfile.sas
  @li ms_deletefile.sas
  @li mv_createfile.sas
  @li mv_deletefoldermember.sas
  @li mx_getcode.sas

  <h4> Related Macros </h4>
  @li mx_append2pgm.test.sas
  @li mx_getcode.sas
  @li mx_createjob.sas

  @author Allan Bowe

**/

%macro mx_append2pgm(loc
    ,inref=0
    ,mdebug=0
)/*/STORE SOURCE*/;

%local platform name shortloc coderef combref work tmpfile viyaref;
%let platform=%mf_getplatform();

%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%if &syscc ne 0 %then %do;
  %put syscc=&syscc - &sysmacroname will not execute in this state;
  %return;
%end;

/* extract name & path from loc */
data _null_;
  length name shortloc $500;
  loc=symget('loc');
  name=scan(loc,-1,'/');
  shortloc=substr(loc,1,length(loc)-length(name)-1);
  call symputx('name',name,'l');
  call symputx('shortloc',shortloc,'l');
run;

/* create a combined fileref with original + appended content */
%let combref=%mf_getuniquefileref();
%let work=%sysfunc(pathname(work));
%let tmpfile=&combref..sas;
filename &combref "&work/&tmpfile" lrecl=32000;

%if &platform=SASVIYA %then %do;
  /* On Viya, read the SAS program file from SAS Drive using filesrvc */
  %let viyaref=%mf_getuniquefileref();
  filename &viyaref filesrvc folderpath="&shortloc";
  data _null_;
    file &combref lrecl=32000 termstr=crlf;
    infile &viyaref("&name..sas") lrecl=32000 end=last;
    input;
    put _infile_;
  run;
  filename &viyaref clear;
  %symdel _FILESRVC_&viyaref._URI;
%end;
%else %do;
  /* For SAS9 and SASJS, use mx_getcode */
  %let coderef=%mf_getuniquefileref();
  %mx_getcode(&loc, outref=&coderef)
  data _null_;
    file &combref lrecl=32000 termstr=crlf;
    infile &coderef lrecl=32000 end=last;
    input;
    put _infile_;
  run;
  filename &coderef clear;
%end;

/* append the new content */
data _null_;
  file &combref lrecl=32000 termstr=crlf mod;
  infile &inref lrecl=32000;
  input;
  put _infile_;
run;

/* delete and recreate the target item */
%if &platform=SASJS %then %do;
  %ms_deletefile(&loc..sas)
  %ms_createfile(&loc..sas, inref=&combref, mdebug=&mdebug)
%end;
%else %if &platform=SASVIYA %then %do;
  %mv_deletefoldermember(path=&shortloc, name=&name..sas, contenttype=file)
  %mv_createfile(path=&shortloc, name=&name..sas, inref=&combref)
%end;
%else %do;
  /* SAS 9 */
  %mm_deletestp(target=&loc)
  %mm_createstp(stpname=&name
    ,filename=&tmpfile
    ,directory=&work
    ,tree=&shortloc
    ,stptype=2
    ,mDebug=&mdebug
    ,minify=NO
  )
%end;

filename &combref clear;

%mend mx_append2pgm;
