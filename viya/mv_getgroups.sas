/**
  @file mv_getgroups.sas
  @brief Creates a dataset with a list of viya groups
  @details Returns exactly GROUPURI, GROUPNAME and GROUPDESC, all character
  variables of length 256. They contain the Viya group ID, name and description
  respectively. An empty response returns the same columns with zero rows.
  Values exceeding 256 bytes cause failure rather than being truncated.
  The request returns at most 10000 groups.

  First, load the macros:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Next, execute:

      %mv_getgroups(outds=work.groups)

  @param [in] access_token_var= (ACCESS_TOKEN)
    The global macro variable to contain the access token
  @param [in] grant_type= (sas_services)
    valid values are "password" or "authorization_code" (unquoted).
  @param [out] outds= (work.viyagroups)
    The library.dataset to be created that contains the list of groups


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_getuniquename.sas

**/

%macro mv_getgroups(access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outds=work.viyagroups
  );
%local oauth_bearer base_uri fname1 libref1 dsid rc idpos namepos descpos
  invalid overflow schema empty;
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

options noquotelenmax;
/* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/groups?limit=10000";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
          "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)
libname &libref1 JSON fileref=&fname1;
%let schema=work.%mf_getuniquename(prefix=mv_groups_);
%mddl_getgroups(&schema)

/* A JSON response without items has no ITEMS table. */
%if not %sysfunc(exist(&libref1..items)) %then %do;
  data &outds;
    if 0 then set &schema;
    stop;
  run;
%end;
%else %do;
  /* Check actual values, not the JSON engine's inferred variable length,
    to avoid rejecting padded short values. */
  %let dsid=%sysfunc(open(&libref1..items,i));
  %let invalid=0;
  %let empty=0;
  %let idpos=0;
  %let namepos=0;
  %let descpos=0;
  %if &dsid=0 %then %let invalid=1;
  %else %do;
    %let idpos=%sysfunc(varnum(&dsid,id));
    %let namepos=%sysfunc(varnum(&dsid,name));
    %let descpos=%sysfunc(varnum(&dsid,description));
    /* An empty nested array can have an ordinal-only ITEMS table. */
    %if &idpos=0 and &namepos=0 and &descpos=0 %then %let empty=1;
    %else %if &idpos=0 or &namepos=0 %then %let invalid=1;
    %else %if %sysfunc(vartype(&dsid,&idpos)) ne C or
      %sysfunc(vartype(&dsid,&namepos)) ne C %then %let invalid=1;
    %if &descpos>0 %then %do;
      %if %sysfunc(vartype(&dsid,&descpos)) ne C %then %let invalid=1;
    %end;
    %let rc=%sysfunc(close(&dsid));
  %end;
  %mp_abort(iftrue=(&invalid ne 0),mac=mv_getgroups,
    msg=%str(Invalid groups response: expected character ID and NAME))
  %if &empty %then %do;
    data &outds;
      if 0 then set &schema;
      stop;
    run;
  %end;
  %else %do;
  %let overflow=0;
  data _null_;
    set &libref1..items;
    if lengthn(id)>256 or lengthn(name)>256
      %if &descpos>0 %then %do;
        or lengthn(description)>256
      %end;
      then call symputx('overflow',1,'L');
  run;
  %mp_abort(iftrue=(&overflow ne 0),mac=mv_getgroups,
    msg=%str(Group ID name or description exceeds 256 bytes))
  data &outds;
    if 0 then set &schema;
    set &libref1..items;
    groupuri=id;
    groupname=name;
    %if &descpos>0 %then %do;
      groupdesc=description;
    %end;
    keep groupuri groupname groupdesc;
  run;
  %end;
%end;


/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend mv_getgroups;
