/**
  @file
  @brief Fetches all groups or the groups for a particular member
  @details  When building applications that run on multiple flavours of SAS, it
  is convenient to use a single macro (like this one) to fetch the groups
  regardless of the flavour of SAS being used

  The alternative would be to compile a generic macro in target-specific
  folders (SASVIYA, SAS9 and SASJS).  This avoids compiling unnecessary macros
  at the expense of a more complex sasjsconfig.json setup.


  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [in] user= (0) Provide the username on which to filter
  @param [in] uid= (0) Provide the userid on which to filter
  @param [in] repo= (foundation) SAS9 only, choose the metadata repo to query
  @param [in] access_token_var= (ACCESS_TOKEN) VIYA only.
    The global macro variable to contain the access token
  @param [in] grant_type= (sas_services) VIYA only.
    Valid values are "password" or "authorization_code" (unquoted).
  @param [out] outds= (work.mx_getgroups) This output dataset will contain the
    list of groups. Format:
|NAME:$32.|DESCRIPTION:$256.|GROUPID:best.|
|---|---|---|
|`SomeGroup `|`A group `|`1`|
|`Another Group`|`this is a different group`|`2`|
|`admin`|`Administrators `|`3`|

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mm_getgroups.sas
  @li ms_getgroups.sas
  @li mv_getgroups.sas
  @li mv_getusergroups.sas

**/

%macro mx_getgroups(
  mdebug=0,
  user=0,
  uid=0,
  repo=foundation,
  access_token_var=ACCESS_TOKEN,
  grant_type=sas_services,
  outds=work.mx_getgroups
)/*/STORE SOURCE*/;
%local platform name shortloc;
%let platform=%mf_getplatform();

%if &platform=SASJS %then %do;
  %ms_getgroups(
    user=&user,
    uid=&uid,
    outds=&outds,
    mdebug=&mdebug
  )
%end;
%else %if &platform=SAS9 or &platform=SASMETA %then %do;
  %if &user=0 %then %let user=;
  %mm_getGroups(
    user=&user
    ,outds=&outds
    ,repo=&repo
    ,mDebug=&mdebug
  )
%end;
%else %if &platform=SASVIYA %then %do;
  %if &user=0 %then %do;
    %mv_getgroups(access_token_var=&access_token_var
      ,grant_type=&grant_type
      ,outds=&outds
    )
  %end;
  %else %do;
    %mv_getusergroups(&user
      ,outds=&outds
      ,access_token_var=&access_token_var
      ,grant_type=&grant_type
    )
  %end;
%end;

%mend mx_getgroups;