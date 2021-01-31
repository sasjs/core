/**
  @file mv_deleteviyafolder.sas
  @brief Creates a viya folder if that folder does not already exist
  @details If not running in Studo 5 +, will expect an oauth token in a global
  macro variable (default ACCESS_TOKEN).

      %mv_createfolder(path=/Public/test/blah)
      %mv_deleteviyafolder(path=/Public/test)


  @param path= The full path of the folder to be deleted
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

**/

%macro mv_deleteviyafolder(path=
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
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
%put &sysmacroname: grant_type=&grant_type;
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%put &sysmacroname: fetching details for &path ;
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/folders/folders/@item?path=&path";
  %if &grant_type=authorization_code %then %do;
    headers "Authorization"="Bearer &&&access_token_var";
  %end;
run;
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put &sysmacroname: Folder &path NOT FOUND - nothing to delete!;
  %return;
%end;
%else %if &SYS_PROCHTTP_STATUS_CODE ne 200 %then %do;
  /*data _null_;infile &fname1;input;putlog _infile_;run;*/
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;

%put &sysmacroname: grab the follow on link ;
%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;
data _null_;
  set &libref1..links;
  if rel='deleteRecursively' then
    call symputx('href',quote("&base_uri"!!trim(href)),'l');
  else if rel='members' then
    call symputx('mref',quote(cats("&base_uri",href,'?recursive=true')),'l');
run;

/* before we can delete the folder, we need to delete the children */
%local fname1a;
%let fname1a=%mf_getuniquefileref();
proc http method='GET' out=&fname1a &oauth_bearer
  url=%unquote(%superq(mref));
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%put &=SYS_PROCHTTP_STATUS_CODE;
%local libref1a;
%let libref1a=%mf_getuniquelibref();
libname &libref1a JSON fileref=&fname1a;

data _null_;
  set &libref1a..items_links;
  if href=:'/folders/folders' then return;
  if rel='deleteResource' then
    call execute('proc http method="DELETE" url='!!quote("&base_uri"!!trim(href))
    !!'; headers "Authorization"="Bearer &&&access_token_var" '
    !!' "Accept"="*/*";run; /**/');
run;

%put &sysmacroname: perform the delete operation ;
%local fname2;
%let fname2=%mf_getuniquefileref();
proc http method='DELETE' out=&fname2 &oauth_bearer
    url=%unquote(%superq(href));
    headers
  %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
  %end;
            'Accept'='*/*'; /**/
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 204 %then %do;
  data _null_; infile &fname2; input; putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
%else %put &sysmacroname: &path successfully deleted;

/* clear refs */
filename &fname1 clear;
filename &fname2 clear;
libname &libref1 clear;

%mend;