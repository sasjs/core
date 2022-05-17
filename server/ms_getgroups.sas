/**
  @file
  @brief Fetches the list of groups from SASjs Server
  @details Fetches the list of groups from SASjs Server and writes them to an
  output dataset.

  Example:

      %ms_getgroups(outds=userlist)

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
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
  @li ms_getusers.test.sas

**/

%macro ms_getgroups(
    outds=work.ms_getgroups
    ,mdebug=0
  );

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getusers.sas
  ,msg=%str(syscc=&syscc on macro entry)
)

%local fref0 fref1 libref optval rc msg;
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

proc http method='GET' headerin=&fref0 out=&fref1
  url="&_sasjs_apiserverurl/SASjsApi/group";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_getgroups.sas
  ,msg=%str(Issue submitting GET query to SASjsApi/group)
)

libname &libref JSON fileref=&fref1;

data &outds;
  length NAME $32 DESCRIPTION $64. GROUPID 8;
  if _n_=1 then call missing(of _all_);
  set &libref..root;
  drop ordinal_root;
run;

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

%mend ms_getgroups;
