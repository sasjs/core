/**
  @file
  @brief Fetches the list of groups from SASjs Server
  @details Fetches all groups, or the groups for a particular user.  When both
  user and uid are provided, user takes precedence.  GROUPURI is the API group
  uid, not the legacy numeric groupid.  Desktop mode returns a synthetic group
  with GROUPURI=1, GROUPNAME=SYSUSERID and a desktop description.

  A failed HTTP request raises a failure and leaves an empty output dataset,
  except that a missing user returns no groups. Empty group arrays produce an
  empty dataset with the model. Descriptions longer than 256 bytes are
  truncated to fit GROUPDESC.

  Example:

      %ms_getgroups(outds=work.groups)
      %ms_getgroups(user=James,outds=work.groups)
      %ms_getgroups(uid=1,outds=work.groups)

  @param [in] mdebug= (0) Set to 1 to enable HTTP debug messages
  @param [in] user= (0) Username used to filter groups
  @param [in] uid= (0) User uid used to filter groups
  @param [out] outds= (work.ms_getgroups) Dataset with exactly GROUPURI,
    GROUPNAME and GROUPDESC, all character length 256.

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas

  <h4> Related Files </h4>
  @li ms_creategroup.sas
  @li ms_getgroups.test.sas

**/
%macro ms_getgroups(user=0,uid=0,outds=work.ms_getgroups,mdebug=0);
%local fref0 fref1 libref optval url table dsid rc schema;

%mp_abort(iftrue=(&syscc ne 0),mac=ms_getgroups.sas
  ,msg=%str(syscc=&syscc on macro entry))

%let schema=work.%mf_getuniquename(prefix=ms_getgroups);
%mddl_getgroups(&schema)

data &outds;
  if 0 then set &schema;
  call missing(groupuri,groupname,groupdesc);
  stop;
run;

%if %sysget(MODE)=desktop %then %do;
  data &outds;
    if 0 then set &schema;
    groupuri='1';
    groupname=symget('sysuserid');
    groupdesc=cats(symget('sysuserid'),' (group - desktop mode)');
    output;
    stop;
  run;
  %return;
%end;

%let fref0=%mf_getuniquefileref();
%let fref1=%mf_getuniquefileref();
%let libref=%mf_getuniquelibref();
%let optval=%sysfunc(getoption(bomfile));
options nobomfile;

data _null_;
  file &fref0 lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  if _n_=1 then put 'accept: application/json';
  put _infile_;
run;

%if %superq(user) ne 0 %then %let url=/SASjsApi/user/by/username/&user;
%else %if %superq(uid) ne 0 %then %let url=/SASjsApi/user/&uid;
%else %let url=/SASjsApi/group;

proc http method='GET' headerin=&fref0 out=&fref1
  url="&_sasjs_apiserverurl.&url";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;
options &optval;

%if &syscc ne 0 or %superq(SYS_PROCHTTP_STATUS_CODE) ne 200 %then %do;
  /* a filtered query for an unknown user or uid is not a failure - the output
    keeps the model with zero rows, matching Viya's unknown-user behaviour */
  %if (%superq(user) ne 0 or %superq(uid) ne 0)
    and %superq(SYS_PROCHTTP_STATUS_CODE)=404 %then %do;
    %put NOTE: MS_GETGROUPS user or uid not found, no groups returned.;
  %end;
  %else %do;
    %put %str(ERR)OR: MS_GETGROUPS HTTP status &SYS_PROCHTTP_STATUS_CODE.;
    %let syscc=8;
  %end;
  filename &fref0 clear;
  filename &fref1 clear;
  %return;
%end;

libname &libref JSON fileref=&fref1;
%if %superq(user)=0 and %superq(uid)=0 %then %let table=root;
%else %let table=groups;

/* Empty arrays have no group fields in the JSON engine's table. */
%let dsid=%sysfunc(open(&libref..&table,i));
%if &dsid %then %do;
  %let rc=%sysfunc(varnum(&dsid,uid));
  %let dsid=%sysfunc(close(&dsid));
  %if &rc %then %do;
    data &outds;
      if 0 then set &schema;
      set &libref..&table(keep=uid name description);
      groupuri=uid;
      groupname=name;
      groupdesc=description;
      keep groupuri groupname groupdesc;
    run;
  %end;
%end;
%else %do;
  %put %str(ERR)OR: MS_GETGROUPS unable to open JSON table &table.;
  %let syscc=8;
%end;
libname &libref clear;
filename &fref0 clear;
filename &fref1 clear;
%mend ms_getgroups;
