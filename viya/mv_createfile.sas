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
  @param [out] outds= (_null_) Output dataset with the uri of the new file

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_isblank.sas
  @li mf_mimetype.sas
  @li mp_abort.sas
  @li mp_base64copy.sas
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

/* prep the source file */
%local fref;
%let fref=%mf_getuniquefileref();

%if %upcase(&intype)=BINARY %then %let fref=&inref;
%else %if %upcase(&intype)=BASE64 %then %do;
  %mp_base64copy(inref=&inref, outref=&fref, action=DECODE)
%end;
%else %put %str(ERR)OR: invalid value for intype: &intype;


%if &mdebug=1 %then %do;
  data _null_;
    infile &fref lrecl=32767;
    input;
    put _infile_;
  run;
%end;


/* create folder if it does not already exist */
%local folderds parenturi;
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


options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%local url mimetype;
%let url=&base_uri/files/files?parentFolderUri=&self_uri;

/* fetch job info */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='POST' out=&fname1 &oauth_bearer in=&fref
  %if "&ctype" = "0" %then %do;
    %let mimetype=%mf_mimetype(%scan(&name,-1,.));
    ct="&mimetype"
  %end;
  %else %do;
    ct="&ctype"
  %end;
  %if "&mimetype"="text/html" %then %do;
    url="&url%str(&)typeDefName=file";
  %end;
  %else %do;
    url="&url";
  %end;

  headers "Accept"="application/json"
  %if &grant_type=authorization_code %then %do;
    "Authorization"="Bearer &&&access_token_var"
  %end;
    "Content-Disposition"= "&contentdisp filename=""&name""; name=""&name"";";
run;
%put &=SYS_PROCHTTP_STATUS_CODE;
%put &=SYS_PROCHTTP_STATUS_PHRASE;
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 201)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
%local libref2;
%let libref2=%mf_getuniquelibref();
libname &libref2 JSON fileref=&fname1;
%put Grabbing the follow on link ;
data &outds;
  set &libref2..links end=last;
  if rel='createChild' then do;
    call symputx('href',quote(cats("&base_uri",href)),'l');
    &dbg put (_all_)(=);
  end;
run;

%put &sysmacroname: File &name successfully created:;%put;
%put    &base_uri%mfv_getpathuri(&path/&name);%put;
%put    &base_uri/SASJobExecution?_file=&path/&name;%put;
%put &sysmacroname:;

%mend mv_createfile;