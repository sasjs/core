/**
  @file mv_getfoldermembers.sas
  @brief Gets a list of folders (and ids) for a given root
  @details Works for both root level and below, oauth or password. Default is
    oauth, and the token is expected in a global ACCESS_TOKEN variable.

        %mv_getfoldermembers(root=/Public)


  @param root= The path for which to return the list of folders
  @param outds= The output dataset to create (default is work.mv_getfolders)
  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values are "password" or "authorization_code" (unquoted).
    The default is authorization_code.


  @version VIYA V.03.04
  @author Allan Bowe
  @source https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_isblank.sas

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
%put &sysmacroname: grant_type=&grant_type;
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
      url='%sysfunc(getoption(servicesbaseurl))/folders/rootFolders';
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
  data _null_;
    set &libref1..links;
    if rel='members' then call symputx('href',quote(trim(href)),'l');
  run;
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

%mend;