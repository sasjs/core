/**
  @file
  @brief Gets a list of folder members (and ids) for a given root
  @details Returns all members for a particular Viya folder.  Works at both root
  level and below, and results are created in an output dataset.

        %mv_getfoldermembers(root=/Public, outds=work.mymembers)


  @param [in] root= (/) The path for which to return the list of folders
  @param [out] outds= (work.mv_getfolders) The output dataset to create. Format:
  |ordinal_root|ordinal_items|creationTimeStamp| modifiedTimeStamp|createdBy|modifiedBy|id| uri|added| type|name|description|
  |---|---|---|---|---|---|---|---|---|---|---|---|
  |1|1|2021-05-25T11:15:04.204Z|2021-05-25T11:15:04.204Z|allbow|allbow|4f1e3945-9655-462b-90f2-c31534b3ca47|/folders/folders/ed701ff3-77e8-468d-a4f5-8c43dec0fd9e|2021-05-25T11:15:04.212Z|child|my_folder_name|My folder Description|

  @param [in] access_token_var= (ACCESS_TOKEN) The global macro variable to
    contain the access token
  @param [in] grant_type= (sas_services) Valid values are:
    @li password
    @li authorization_code
    @li detect
    @li sas_services

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

  <h4> Related Macros </h4>
  @li mv_createfolder.sas
  @li mv_deletefoldermember.sas
  @li mv_deleteviyafolder.sas
  @li mv_getfoldermembers.test.sas

**/

%macro mv_getfoldermembers(root=/
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outds=mv_getfolders
  );
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

%if %mf_isblank(&root)=1 %then %let root=/;

options noquotelenmax;

/* request the client details */
%local fname1 libref1;
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%if "&root"="/" %then %do;
  /* if root just list root folders */
  proc http method='GET' out=&fname1 &oauth_bearer
      url="&base_uri/folders/rootFolders?limit=1000";
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  libname &libref1 JSON fileref=&fname1;
  data &outds;
    set &libref1..items;
  run;
%end;
%else %do;
  /* first get parent folder id */
  proc http method='GET' out=&fname1 &oauth_bearer
      url="&base_uri/folders/folders/@item?path=&root";
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  /*data _null_;infile &fname1;input;putlog _infile_;run;*/
  libname &libref1 JSON fileref=&fname1;
  /* now get the followon link to list members */
  %local href cnt;
  %let cnt=0;
  data _null_;
    set &libref1..links;
    if rel='members' then do;
      url=cats("'","&base_uri",href,"?limit=10000'");
      call symputx('href',url,'l');
      call symputx('cnt',1,'l');
    end;
  run;
  %if &cnt=0 %then %do;
    %put NOTE:;%put NOTE-  No members found in &root!!;%put NOTE-;
    %return;
  %end;
  %local fname2 libref2;
  %let fname2=%mf_getuniquefileref();
  %let libref2=%mf_getuniquelibref();
  proc http method='GET' out=&fname2 &oauth_bearer
      url=%unquote(%superq(href));
  %if &grant_type=authorization_code %then %do;
      headers "Authorization"="Bearer &&&access_token_var";
  %end;
  run;
  libname &libref2 JSON fileref=&fname2;
  data &outds;
    set &libref2..items;
  run;
  filename &fname2 clear;
  libname &libref2 clear;
%end;


/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend mv_getfoldermembers;