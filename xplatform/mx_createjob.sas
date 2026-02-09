/**
  @file mx_createjob.sas
  @brief Create a job in SAS 9, Viya or SASjs
  @details Creates a Stored Process in SAS 9, a Job Execution Service in SAS
  Viya, or a Stored Program on SASjs Server - depending on the executing
  environment.

Usage:

    %* compile macros ;
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* write some code;
    filename ft15f001 temp;
    parmcards4;
        data example1;
          set sashelp.class;
        run;
    ;;;;

    %* create the job;
    %mx_createjob(path=/Public/app/jobs,name=myjob,replace=YES)

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mm_createstp.sas
  @li ms_createfile.sas
  @li mv_createjob.sas

  @param [in,out] path= The full folder path where the job will be created
  @param [in,out] name= Job name.  Avoid spaces.
  @param [in] desc= The description of the job (optional)
  @param [in] precode= Space separated list of filerefs, pointing to the code
    that needs to be attached to the beginning of the job (optional)
  @param [in] code= (ft15f001) Space seperated fileref(s) of the actual code to
    be added
  @param [in] replace= (YES) Select YES to replace any existing job in that
    location
  @param [in] mDebug= (0) set to 1 to show debug messages in the log

  @author Allan Bowe

  <h4> Related Macros </h4>
  @li mx_createjob.test.sas
  @li mx_createwebservice.sas

**/

%macro mx_createjob(path=HOME
    ,name=initJob
    ,precode=
    ,code=ft15f001
    ,desc=This job was created by the mx_createjob macro
    ,replace=YES
    ,mdebug=0
)/*/STORE SOURCE*/;

%if &syscc ge 4 %then %do;
  %put syscc=&syscc - &sysmacroname will not execute in this state;
  %return;
%end;

/* combine precode and code into a single file */
%local tempref x fref freflist;
%let tempref=%mf_getuniquefileref();
%local work tmpfile;
%let work=%sysfunc(pathname(work));
%let tmpfile=&tempref..sas;
filename &tempref "&work/&tmpfile";
%let freflist=&precode &code ;
%do x=1 %to %sysfunc(countw(&freflist));
  %let fref=%scan(&freflist,&x);
  %put &sysmacroname: adding &fref;
  data _null_;
    file &tempref lrecl=3000 termstr=crlf mod;
    infile &fref lrecl=3000;
    input;
    put _infile_;
  run;
%end;

%local platform; %let platform=%mf_getplatform();
%if &platform=SASVIYA %then %do;
  %if "&path"="HOME" %then %let path=/Users/&sysuserid/My Folder;
  %mv_createjob(path=&path
    ,name=&name
    ,code=&tempref
    ,desc=&desc
    ,replace=&replace
  )
%end;
%else %if &platform=SASJS %then %do;
  %if "&path"="HOME" %then %let path=/Users/&_sasjs_username/My Folder;
  %ms_createfile(&path/&name..sas
    ,inref=&tempref
    ,mdebug=&mdebug
  )
%end;
%else %do;
  %if "&path"="HOME" %then %let path=/User Folders/&_METAPERSON/My Folder;
  %mm_createstp(stpname=&name
    ,filename=&tmpfile
    ,directory=&work
    ,tree=&path
    ,stpdesc=&desc
    ,mDebug=&mdebug
  )
%end;
filename &tempref clear;
%mend mx_createjob;
