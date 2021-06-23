/**
  @file
  @brief Creates a file in SAS Drive
  @details Creates a file in SAS Drive and adds the appropriate content type.
  If the parent folder does not exist, it is created.

  Usage:

      filename myfile temp;
      data _null_;
        file myfile;
        put 'something';
      run;
      %mv_createfile(path=/Public/temp,name=newfile.txt,inref=myfile)


  @param [in] path= The parent folder in which to create the file
  @param [in] name= The name of the file to be created
  @param [in] inref= The fileref pointing to the file to be uploaded
  @param [in] intype= (BINARY) The type of the input data.  Valid values:
    @li BINARY File is copied byte for byte using the mp_binarycopy.sas macro.
    @li BASE64 File will be first decoded using the mp_base64.sas macro, then
      loaded byte by byte to SAS Drive.
  @param [in] contentdisp= (inline) Content Disposition. Example values:
    @li inline
    @li attachment

  @param [in] access_token_var= The global macro variable to contain the access
    token, if using authorization_code grant type.
  @param [in] grant_type= (sas_services) Valid values are:
    @li password
    @li authorization_code
    @li sas_services

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  @version VIYA V.03.05
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_isblank.sas
  @li mp_abort.sas
  @li mp_base64copy.sas
  @li mp_binarycopy.sas
  @li mv_createfolder.sas

**/

%macro mv_createfile(path=
    ,name=
    ,inref=
    ,intype=BINARY
    ,contentdisp=inline
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,mdebug=0
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
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)

%mp_abort(iftrue=(%mf_isblank(&path)=1 or %length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%mf_isblank(&name)=1 or %length(&name)=1)
  ,mac=&sysmacroname
  ,msg=%str(name value with length >1 must be provided)
)

/* create folder if it does not already exist */
%mv_createfolder(path=&path
  ,access_token_var=&access_token_var
  ,grant_type=&grant_type
  ,mdebug=&mdebug
)

/* create file with relevant options */
%local fref;
%let fref=%mf_getuniquefileref();
filename &fref filesrvc
  folderPath="&path"
  filename="&name"
  cdisp="&contentdisp"
  lrecl=1048544;

%if &intype=BINARY %then %do;
  %mp_binarycopy(inref=&inref, outref=&fref)
%end;
%else %if &intype=BASE64 %then %do;
  %mp_base64copy(inref=&inref, outref=&fref, action=DECODE)
%end;

filename &fref clear;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%put &sysmacroname: File &name successfully created in &path;
%put &sysmacroname:;%put;
%put    &base_uri/SASJobExecution?_file=&path/&name;%put;
%put &sysmacroname:;

%mend mv_createfile;