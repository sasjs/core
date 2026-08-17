/**
  @file
  @brief Creates a file in the logical filesystem of the target platform
  @details When building applications that run on multiple flavours of SAS, it
  is convenient to use a single macro (like this one) to write a text file -
  eg a settings file - without worrying about the platform primitive.

  The file is created in the logical filesystem of the target platform (SAS
  Content folder, SASjs Drive, or metadata folder).  No file is created on a
  physical filesystem.  Platform behaviour:
  - SASVIYA: creates a SAS Content file (%mv_createfile)
  - SASJS: creates a file on SASjs Drive (%ms_createfile)
  - SAS 9 / metadata: SAS 9 has no "file" concept for Stored Process content,
    so a type 2 Stored Process is created in metadata (%mm_createstp), with
    the content loaded as the STP source code

  The alternative would be to compile a generic macro in target-specific
  folders (SASVIYA, SAS9 and SASJS).  This avoids compiling unnecessary macros
  at the expense of a more complex sasjsconfig.json setup.

  Usage:

      filename ft15f001 temp;
      data _null_;
        file ft15f001;
        put '%let mysetting=42;';
      run;

      %* viya:  /Public/app/myapp/settings (Files Service)      ;
      %* sasjs: /Public/app/myapp/settings.sas (SASjs Drive)    ;
      %* sas9:  /User Folders/sasdemo/myapp/settings (metadata) ;
      %let filepath=/Public/app/myapp/settings;
      %mx_createfile(&filepath, inref=ft15f001)

  @param [in] filepath The full path of the file to create, INCLUDING the
    filename.  On SASjs Server the name should carry the .sas extension if it
    will be executed as a Stored Program.
  @param [in] inref= (0) The fileref containing the file content
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mm_createstp.sas
  @li ms_createfile.sas
  @li mv_createfile.sas

  <h4> Related Macros </h4>
  @li mx_createwebservice.sas
  @li mx_getcode.sas

**/

%macro mx_createfile(filepath
    ,inref=0
    ,mdebug=0
)/*/STORE SOURCE*/;

%local platform name shortloc;
%let platform=%mf_getplatform();

%if &platform=SASJS %then %do;
  %ms_createfile(%superq(filepath), inref=&inref, mdebug=&mdebug)
%end;
%else %if &platform=SASVIYA %then %do;
  /* extract name & path from &filepath */
  data _null_;
    filepath=symget('filepath');
    name=scan(filepath,-1,'/');
    shortloc=substr(filepath,1,length(filepath)-length(name)-1);
    call symputx('name',name,'l');
    call symputx('shortloc',shortloc,'l');
  run;
  %mv_createfile(path=%superq(shortloc)
    ,name=%superq(name)
    ,inref=&inref
    ,mdebug=&mdebug
  )
%end;
%else %if &platform=SAS9 or &platform=SASMETA %then %do;
  /* no file concept - create a type 2 STP (source code saved in metadata).
    The mm_createstp macro requires a physical file, so copy the inref
    content to WORK first.  It then loads the source code, meaning no
    separate mm_updatestpsourcecode call is needed. */
  data _null_;
    filepath=symget('filepath');
    name=scan(filepath,-1,'/');
    shortloc=substr(filepath,1,length(filepath)-length(name)-1);
    call symputx('name',name,'l');
    call symputx('shortloc',shortloc,'l');
  run;
  data _null_;
    infile &inref lrecl=32767;
    file "%sysfunc(getoption(work))/%superq(name).sas" lrecl=32767;
    input;
    put _infile_;
  run;
  %mm_createstp(stpname=%superq(name)
    ,tree=%superq(shortloc)
    ,filename=%superq(name).sas
    ,directory=%sysfunc(getoption(work))
    ,stptype=2
    ,mdebug=&mdebug
  )
%end;
%else %put &sysmacroname: &platform is unsupported!!!;

%mend mx_createfile;
