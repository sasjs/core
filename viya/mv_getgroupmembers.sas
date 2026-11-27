/**
  @file mv_getgroupmembers.sas
  @brief Creates a dataset with a list of group members
  @details First, be sure you have an access token (which requires an app token)

  Using the macros here:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Now we can run the macro!

      %mv_getgroupmembers(All Users)

  The output contains exactly these member columns on every path:

      version num(8),
      id char(256),
      name char(256),
      providerId char(32),
      type char(32)

  Other identities API fields and JSON engine ordinal columns are not included.
  `type` is the member type (user or group). A group with no members, and a
  group id the server does not know, return these columns with zero rows.

  Output schema change: callers that used `implicit`, `ordinal_root`,
  `ordinal_items`, or other API fields must stop relying on those columns.
  Obtain needed additional information from the appropriate identities API;
  JSON ordinals are engine-generated metadata.

  @param [in] group Group id for which to return group members
  @param [in] access_token_var= (ACCESS_TOKEN)
    The global macro variable to contain the access token
  @param [in] grant_type= (sas_services)
    valid values are "password" or "authorization_code" (unquoted).
  @param [out] outds= (work.viyagroupmembers)
    The library.dataset to be created that contains the list of members

  id and name are declared at $256, the longest active directory can hold for
  a display name or a SAM account name.  The $43 they used to carry truncated
  anything longer, and a truncation fails the step on some platforms.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_existvar.sas

**/

%macro mv_getgroupmembers(group
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outds=work.viyagroupmembers
  );
%local oauth_bearer libref1;
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

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/groups/&group/members?limit=10000";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
          "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put NOTE:  Group &group not found!!;
  /* the same documented columns and zero rows as a group with no members -
    call missing alone would output one all-missing observation */
  data &outds;
    length version 8 id $256 name $256 providerId $32 type $32;
    call missing(of _all_);
    stop;
  run;
%end;
%else %do;
  %mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
    ,mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
  %let libref1=%mf_getuniquelibref();
  libname &libref1 JSON fileref=&fname1;
  /* a group with no members returns a collection whose items dataset carries no
    member columns, so a straight SET would raise "Variable id is uninitialized"
    and leave syscc dirty.  Only copy when there is something to copy.  The
    member columns are declared on both paths. The lengths are declared because
    the JSON engine sizes its columns to the longest value in the payload:
    $256 is the longest an active directory display name or SAM account name
    can hold, and a shorter declaration lets the engine report "Multiple
    lengths were specified" on a later member. */
  %local itemsds hasvars;
  %let itemsds=&libref1..items;
  %let hasvars=0;
  %if %sysfunc(exist(&itemsds))=1 %then %do;
    %if %mf_existvar(&itemsds,id)>0 %then %let hasvars=1;
  %end;
  data &outds;
    length version 8 id $256 name $256 providerId $32 type $32;
    keep version id name providerId type;
    call missing(of _all_);
    %if &hasvars=1 %then %do;
      set &itemsds;
      /* the engine emits one all-missing row for an empty collection */
      if missing(id) then delete;
    %end;
    %else %do;
      stop;
    %end;
  run;
  libname &libref1 clear;
%end;

/* clear refs */
filename &fname1 clear;

%mend mv_getgroupmembers;
