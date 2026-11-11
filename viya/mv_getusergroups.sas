/**
  @file mv_getusergroups.sas
  @brief Creates a dataset with a list of groups for a particular user
  @details If using outside of Viya SPRE, then an access token is needed.

  Compile the macros here:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Then run the macro!

      %mv_getusergroups(&sysuserid,outds=users)

  @param [in] user The username for which to return the list of groups
  @param [in] access_token_var= (ACCESS_TOKEN)
    The global macro variable to contain the access token
  @param [in] grant_type= (sas_services)
    Valid values are "password" or "authorization_code" (unquoted).
  @param [out] outds= (work.mv_getusergroups)
    The library.dataset to be created that contains the list of groups. Format:
  |ordinal_root|ordinal_items|version|id|implicit|name|providerId|
  |---|---|---|---|---|---|---|
  |1|1|1|viyagroup18|0|SAS Viyagroup18|ldap|

  A user the server does not know returns the columns above with zero rows.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

**/

%macro mv_getusergroups(user
    ,outds=work.mv_getusergroups
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
options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
%let libref1=%mf_getuniquelibref();

proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/identities/users/&user/memberships?limit=10000";
  headers
%if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
%end;
          "Accept"="application/json";
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/
/* a 404 answers with a document that carries no items dataset, so the output
  is written here instead, with the documented columns and zero rows, and the
  JSON libref is never assigned */
%if &SYS_PROCHTTP_STATUS_CODE=404 %then %do;
  %put NOTE:  User &user not found!!;
  data &outds;
    length ordinal_root 8 ordinal_items 8 version 8
      id $256 implicit 8 name $256 providerId $32;
    call missing(of _all_);
    stop;
  run;
  filename &fname1 clear;
  %return;
%end;
%else %do;
  %mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
    ,mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
libname &libref1 JSON fileref=&fname1;

/* the documented columns are declared on both paths, so a caller reads the
  same columns whether the user has memberships or is unknown.  The lengths
  are at least the engine's own, which are sized to the payload */
data &outds;
  length ordinal_root 8 ordinal_items 8 version 8
    id $256 implicit 8 name $256 providerId $32;
  set &libref1..items;
run;

/* clear refs */
filename &fname1 clear;
libname &libref1 clear;

%mend mv_getusergroups;
