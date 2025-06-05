/**
  @file
  @brief Creates a file in SAS Drive using the API method
  @details Creates a file in SAS Drive using the API interface.
  If the parent folder does not exist, it is created.
  The API approach is more flexible than using the filesrvc engine of the
  filename statement, as it provides more options.

  SAS docs:  https://developer.sas.com/rest-apis/files/createNewFile

  Usage:

      filename myfile temp;
      data _null_;
        file myfile;
        put 'something';
      run;
      %mv_createfile(path=/Public/temp,name=newfile.txt,inref=myfile)

  The macro also supports find & replace (used by the SASjs Streaming App
  build program).  This allows one string to be replaced by another at the
  point at which the file is created.  This is done by passing in the NAMES of
  the macro variables containing the values to be swapped, eg:

      filename fref temp;
      data _null_;
        file fref;
        put 'whenever life gets you down, Mrs Brown..';
      run;
      %let f=Mrs Brown;
      %let r=just remember that you're standing on a planet that's evolving;
      %mv_createfile(path=/Public,name=life.md,inref=fref,fin,swap=f r)


  @param [in] path= The parent (SAS Drive) folder in which to create the file
  @param [in] name= The name of the file to be created
  @param [in] inref= The fileref pointing to the file to be uploaded
  @param [in] intype= (BINARY) The type of the input data.  Valid values:
    @li BINARY File is copied byte for byte using the mp_binarycopy.sas macro.
    @li BASE64 File will be first decoded using the mp_base64.sas macro, then
      loaded byte by byte to SAS Drive.
  @param [in] contentdisp= (attchment) Content Disposition. Example values:
    @li inline
    @li attachment
  @param [in] ctype= (0) The actual MIME type of the file (if blank will be
    determined based on file extension))
  @param [in] access_token_var= The global macro variable to contain the access
    token, if using authorization_code grant type.
  @param [in] grant_type= (sas_services) Valid values are:
    @li password
    @li authorization_code
    @li sas_services
  @param [in] force= (YES) Will overwrite (delete / recreate) files by default.
    Set to NO to abort if a file already exists in that location.
  @param pin] swap= (0) Provide two macro variable NAMES that contain the values
    to be swapped, eg swap=find replace (see also the example above)
  @param [out] outds= (_null_) Output dataset with the uri of the new file

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_isblank.sas
  @li mf_mimetype.sas
  @li mfv_getpathuri.sas
  @li mp_abort.sas
  @li mp_base64copy.sas
  @li mp_replace.sas
  @li mv_createfolder.sas

  <h4> Related Macros</h4>
  @li mv_createfile.sas

**/

%macro mv_createfile(path=
    ,name=
    ,inref=
    ,intype=BINARY
    ,contentdisp=attachment
    ,ctype=0
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,mdebug=0
    ,outds=_null_
    ,force=YES
    ,swap=0
  );
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
  %let oauth_bearer=oauth_bearer=sas_services;
  %let &access_token_var=;
%end;

%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=MV_CREATEFILE
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%mp_abort(iftrue=(%mf_isblank(&path)=1 or %length(&path)=1)
  ,mac=MV_CREATEFILE
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%mf_isblank(&name)=1 or %length(&name)=1)
  ,mac=MV_CREATEFILE
  ,msg=%str(name value with length >1 must be provided)
)

/* prep the source file */
%local fref;
%let fref=%mf_getuniquefileref();

%if %upcase(&intype)=BINARY %then %let fref=&inref;
%else %if %upcase(&intype)=BASE64 %then %do;
  %mp_base64copy(inref=&inref, outref=&fref, action=DECODE)
%end;
%else %put %str(ERR)OR: invalid value for intype: &intype;

%if "&swap" ne "0" %then %do;
  %mp_replace("%sysfunc(pathname(&fref))"
    ,findvar=%scan(&swap,1,%str( ))
    ,replacevar=%scan(&swap,2,%str( ))
  )
%end;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fref lrecl=32767;
    input;
    put _infile_;
  run;
%end;

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* create folder if it does not already exist */
%local folderds self_uri;
%let folderds=%mf_getuniquename(prefix=folderds);
%mv_createfolder(path=&path
  ,access_token_var=&access_token_var
  ,grant_type=&grant_type
  ,mdebug=&mdebug
  ,outds=&folderds
)
data _null_;
  set &folderds;
  call symputx('self_uri',self_uri,'l');
run;

/* abort or delete if file already exists */
%let force=%upcase(&force);
%local fileuri ;
%let fileuri=%mfv_getpathuri(&path/&name);
%mp_abort(iftrue=(%mf_isblank(&fileuri)=0 and &force ne YES)
  ,mac=MV_CREATEFILE
  ,msg=%str(File &path/&name already exists and force=&force)
)

%if %mf_isblank(&fileuri)=0 and &force=YES %then %do;
  proc http method="DELETE" url="&base_uri&fileuri" &oauth_bearer;
    headers
  %if &grant_type=authorization_code %then %do;
        "Authorization"="Bearer &&&access_token_var"
  %end;
        "Accept"="*/*";
  run;
  %put &sysmacroname DELETE &base_uri&fileuri;
  %if &SYS_PROCHTTP_STATUS_CODE ne 204 %then %do;
    %put &=SYS_PROCHTTP_STATUS_CODE &=SYS_PROCHTTP_STATUS_PHRASE;
  %end;
%end;

%local url mimetype ext;
%let url=&base_uri/files/files?parentFolderUri=&self_uri;
%let ext=%upcase(%scan(&name,-1,.));

/* fetch job info */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='POST' out=&fname1 &oauth_bearer in=&fref
  %if "&ctype" = "0" %then %do;
    %let mimetype=%mf_mimetype(&ext);
    ct="&mimetype"
  %end;
  %else %do;
    ct="&ctype"
  %end;
  %if "&ext"="HTML" or "&ext"="CSS" or "&ext"="JS" or "&ext"="PNG"
  or "&ext"="SVG" %then %do;
    url="&url%str(&)typeDefName=file";
  %end;
  %else %do;
    url="&url";
  %end;

  headers "Accept"="application/json"
  %if &grant_type=authorization_code %then %do;
    "Authorization"="Bearer &&&access_token_var"
  %end;
  "Content-Disposition"=
  %if "&ext"="SVG" or "&ext"="HTML" %then %do;
    "filename=""&name"";"
  %end;
  %else %do;
    "&contentdisp filename=""&name""; name=""&name"";"
  %end;
  ;
run;
%if &mdebug=1 %then %put &sysmacroname POST &=url
  &=SYS_PROCHTTP_STATUS_CODE &=SYS_PROCHTTP_STATUS_PHRASE;
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 201)
  ,mac=MV_CREATEFILE
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
%local libref2;
%let libref2=%mf_getuniquelibref();
libname &libref2 JSON fileref=&fname1;
/* Grab the follow on link */
data &outds;
  set &libref2..links end=last;
  if rel='createChild' then do;
    call symputx('href',quote(cats("&base_uri",href)),'l');
    &dbg put (_all_)(=);
  end;
run;

%put &sysmacroname: &name created at %mfv_getpathuri(&path/&name);%put;
%put    &base_uri/SASJobExecution?_file=&path/&name;%put;

%mend mv_createfile;