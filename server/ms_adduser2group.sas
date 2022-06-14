/**
  @file
  @brief Adds a user to a group on SASjs Server
  @details Adds a user to a group based on userid and groupid.  Both user and
  group must already exist.

  Examples:

      %ms_adduser2group(uid=1,gid=1)


  @param [in] uid= (0) The User ID to be added
  @param [in] gid= (0) The Group ID to contain the new user
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [out] outds= (work.ms_adduser2group) This output dataset will contain
    the new list of group members, eg:
|DISPLAYNAME:$18.|USERNAME:$10.|ID:best.|
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
  @li ms_creategroup.sas
  @li ms_createuser.sas

**/

%macro ms_adduser2group(uid=0
    ,gid=0
    ,outds=work.ms_adduser2group
    ,mdebug=0
  );

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_adduser2group.sas
  ,msg=%str(syscc=&syscc on macro entry)
)

%local fref0 fref1 fref2 libref optval rc msg;
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
  %put _local_;
  data _null_;
    infile &fref0;
    input;
    put _infile_;
  run;
%end;

proc http method='POST' headerin=&fref0 out=&fref1
  url="&_sasjs_apiserverurl/SASjsApi/group/&gid/&uid";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_adduser2group.sas
  ,msg=%str(Issue submitting query to SASjsApi/group)
)

libname &libref JSON fileref=&fref1;

data &outds;
  set &libref..users;
  drop ordinal_root ordinal_users;
%if &mdebug=1 %then %do;
  putlog _all_;
%end;
run;


%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_creategroup.sas
  ,msg=%str(Issue reading response JSON)
)

/* reset options */
options &optval;

%if &mdebug=0 %then %do;
  filename &fref0 clear;
  filename &fref1 clear;
  libname &libref clear;
%end;
%else %do;
  data _null_;
    infile &fref1;
    input;
    putlog _infile_;
  run;
%end;

%mend ms_adduser2group;
