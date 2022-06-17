/**
  @file
  @brief Fetches the list of groups from SASjs Server
  @details Fetches the list of groups from SASjs Server and writes them to an
  output dataset.  Provide a username to filter for the groups for a particular
  user.

  Example:

      %ms_getgroups(outds=userlist)

  With filter on username:

      %ms_getgroups(outds=userlist, user=James)

  With filter on userid:

      %ms_getgroups(outds=userlist, uid=1)

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [in] user= (0) Provide the username on which to filter
  @param [in] uid= (0) Provide the userid on which to filter
  @param [out] outds= (work.ms_getgroups) This output dataset will contain the
    list of groups. Format:
|NAME:$32.|DESCRIPTION:$64.|GROUPID:best.|
|---|---|---|
|`SomeGroup `|`A group `|`1`|
|`Another Group`|`this is a different group`|`2`|
|`admin`|`Administrators `|`3`|


  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_abort.sas

  <h4> Related Files </h4>
  @li ms_creategroup.sas
  @li ms_getgroups.test.sas

**/

%macro ms_getgroups(
  user=0,
  uid=0,
  outds=work.ms_getgroups,
  mdebug=0
);

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getgroups.sas
  ,msg=%str(syscc=&syscc on macro entry)
)

%local fref0 fref1 libref optval rc msg url;

%if %sysget(MODE)=desktop %then %do;
  /* groups api does not exist in desktop mode */
  data &outds;
    length NAME $32 DESCRIPTION $64. GROUPID 8;
    name="&sysuserid";
    description="&sysuserid (group - desktop mode)";
    groupid=1;
    output;
    stop;
  run;
  %return;
%end;

%let fref0=%mf_getuniquefileref();
%let fref1=%mf_getuniquefileref();
%let libref=%mf_getuniquelibref();

/* avoid sending bom marker to API */
%let optval=%sysfunc(getoption(bomfile));
options nobomfile;

data _null_;
  file &fref0 lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  if _n_=1 then put "accept: application/json";
  put _infile_;
run;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fref0;
    input;
    put _infile_;
  run;
%end;

%if "&user" ne "0" %then %let url=/SASjsApi/user/by/username/&user;
%else %if "&uid" ne "0" %then %let url=/SASjsApi/user/&uid;
%else %let url=/SASjsApi/group;


proc http method='GET' headerin=&fref0 out=&fref1
  url="&_sasjs_apiserverurl.&url";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getgroups.sas
  ,msg=%str(Issue submitting GET query to SASjsApi)
)

libname &libref JSON fileref=&fref1;

%if "&user"="0" and "&uid"="0" %then %do;
  data &outds;
    length NAME $32 DESCRIPTION $64. GROUPID 8;
    if _n_=1 then call missing(of _all_);
    set &libref..root;
    drop ordinal_root;
  run;
%end;
%else %do;
  data &outds;
    length NAME $32 DESCRIPTION $64. GROUPID 8;
    if _n_=1 then call missing(of _all_);
    set &libref..groups;
    drop ordinal_:;
  run;
%end;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getgroups.sas
  ,msg=%str(Issue reading response JSON)
)

/* reset options */
options &optval;

%if &mdebug=1 %then %do;
  filename &fref0 clear;
  filename &fref1 clear;
  libname &libref clear;
%end;

%mend ms_getgroups;
