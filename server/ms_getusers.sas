/**
  @file
  @brief Fetches the list of users from SASjs Server
  @details Fetches the list of users from SASjs Server and writes them to an
  output dataset.  Can also be filtered, for a particular group.

  Example:

      %ms_getusers(outds=userlist)

  Filtering for a group by group name:

      %ms_getusers(outds=work.groupmembers, group=GROUPNAME)

  Filtering for a group by group id:

      %ms_getusers(outds=work.groupmembers, gid=1)

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [in] group= (0) Set to a group name to filter members for that group
  @param [in] gid= (0) Set to a group id to filter members for that group
  @param [out] outds= (work.ms_getusers) This output dataset will contain the
    list of user accounts. Format:
|DISPLAYNAME:$60.|USERNAME:$30.|ID:best.|
|---|---|---|
|`Super Admin `|`secretuser `|`1`|
|`Sabir Hassan`|`sabir`|`2`|
|`Mihajlo Medjedovic `|`mihajlo `|`3`|
|`Ivor Townsend `|`ivor `|`4`|
|`New User `|`newuser `|`5`|


  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_abort.sas

  <h4> Related Files </h4>
  @li ms_createuser.sas
  @li ms_getgroups.sas
  @li ms_getusers.test.sas

**/

%macro ms_getusers(
  outds=work.ms_getusers,
  group=0,
  gid=0,
  mdebug=0
);

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getusers.sas
  ,msg=%str(syscc=&syscc on macro entry)
)

%local fref0 fref1 libref optval rc msg url;
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

%if "&group" ne "0" %then %let url=/SASjsApi/group/by/groupname/&group;
%else %if "&gid" ne "0" %then %let url=/SASjsApi/group/&gid;
%else %let url=/SASjsApi/user;

proc http method='GET' headerin=&fref0 out=&fref1
  url="&_sasjs_apiserverurl.&url";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;


%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getusers.sas
  ,msg=%str(Issue submitting API query)
)

libname &libref JSON fileref=&fref1;

%if "&group"="0" and "&gid"="0" %then %do;
  data &outds;
    length DISPLAYNAME $60 USERNAME:$30 ID 8;
    set &libref..root;
    drop ordinal_root;
  run;
%end;
%else %do;
  data &outds;
    length DISPLAYNAME $60 USERNAME:$30 ID 8;
    set &libref..users;
    drop ordinal_root ordinal_users;
  run;
%end;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getusers.sas
  ,msg=%str(Issue reading response JSON)
)

/* reset options */
options &optval;

%if &mdebug=1 %then %do;
  filename &fref0 clear;
  filename &fref1 clear;
  libname &libref clear;
%end;

%mend ms_getusers;
