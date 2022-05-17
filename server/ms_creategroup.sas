/**
  @file
  @brief Creates a group on SASjs Server
  @details Creates a group on SASjs Server with the following attributes:

  @li name
  @li description
  @li isActive

  Examples:

      %ms_creategroup(mynewgroup)

      %ms_creategroup(mynewergroup, desc=The group description)

  @param [in] groupname The group name to create.  No spaces or special chars.
  @param [in] desc= (0) If no description provided, group name will be used.
  @param [in] isactive= (true) Set to false to create an inactive group.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [out] outds= (work.ms_creategroup) This output dataset will contain the
    values from the JSON response (such as the id of the new group)
|DESCRIPTION:$1.|GROUPID:best.|ISACTIVE:best.|NAME:$11.|
|---|---|---|---|
|`The group description`|`2 `|`1 `|`mynewergroup `|



  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_abort.sas

  <h4> Related Files </h4>
  @li ms_creategroup.test.sas
  @li ms_getgroups.sas

**/

%macro ms_creategroup(groupname
    ,desc=0
    ,isactive=true
    ,outds=work.ms_creategroup
    ,mdebug=0
  );

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_creategroup.sas
  ,msg=%str(syscc=&syscc on macro entry)
)

%local fref0 fref1 fref2 libref optval rc msg;
%let fref0=%mf_getuniquefileref();
%let fref1=%mf_getuniquefileref();
%let fref2=%mf_getuniquefileref();
%let libref=%mf_getuniquelibref();

/* avoid sending bom marker to API */
%let optval=%sysfunc(getoption(bomfile));
options nobomfile;

data _null_;
  file &fref0 termstr=crlf;
  name=quote(cats(symget('groupname')));
  description=quote(cats(symget('desc')));
  if cats(description)='"0"' then description=name;
  isactive=symget('isactive');
%if &mdebug=1 %then %do;
  putlog _all_;
%end;

  put '{'@;
  put '"name":' name @;
  put ',"description":' description @;
  put ',"isActive":' isactive @;
  put '}';
run;

data _null_;
  file &fref1 lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  if _n_=1 then do;
    put "Content-Type: application/json";
    put "accept: application/json";
  end;
  put _infile_;
run;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fref0;
    input;
    put _infile_;
  data _null_;
    infile &fref1;
    input;
    put _infile_;
  run;
%end;

proc http method='POST' in=&fref0 headerin=&fref1 out=&fref2
  url="&_sasjs_apiserverurl/SASjsApi/group";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_creategroup.sas
  ,msg=%str(Issue submitting query to SASjsApi/group)
)

libname &libref JSON fileref=&fref2;

data &outds;
  set &libref..root;
  drop ordinal_root;
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
  filename &fref2 clear;
  libname &libref clear;
%end;
%else %do;
  data _null_;
    infile &fref2;
    input;
    putlog _infile_;
  run;
%end;

%mend ms_creategroup;
