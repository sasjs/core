/**
  @file
  @brief Testing mv_getgroups macro

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li mf_existvar.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas
  @li mv_getgroups.sas

**/

/* JSON engine globals depend on the libref allocated in this session. */
%macro group_scope_compare(desc=);
  %local json_globals;
  %let json_globals=;
  proc sql noprint;
    select distinct name into :json_globals separated by ' '
    from dictionary.macros
    where scope='GLOBAL' and prxmatch(
      '/^MC(\d{1,6}|LIB\d{1,3})_JAD(P\d+LEN|PNUM|VLEN)$/i',strip(name));
  quit;
  %mp_assertscope(COMPARE,ignorelist=&json_globals
    ,desc=&desc,outds=work.test_results)
%mend group_scope_compare;

%mddl_getgroups(work.groupmodel)

%mp_assertscope(SNAPSHOT)
%mv_getgroups(outds=work.viyagroups)
%group_scope_compare(desc=mv_getgroups does not leak scope)
%mp_assertmodel(work.viyagroups,base=work.groupmodel,key=groupuri,
  desc=Groups have the exact model and unique nonmissing identifiers,
  outds=work.test_results
)
/* Independently retrieve the same resource to verify all rows and values. */
%macro check_group_values();
  %local base_uri fref lref hasdesc hasitems hasid mismatches;
  %let base_uri=%mf_getplatform(VIYARESTAPI);
  %let fref=%mf_getuniquefileref();
  %let lref=%mf_getuniquelibref();
  proc http method='GET' out=&fref oauth_bearer=sas_services
    url="&base_uri/identities/groups?limit=10000";
    headers "Accept"="application/json";
  run;
  %mp_assert(iftrue=(&SYS_PROCHTTP_STATUS_CODE=200),
    desc=Independent groups request succeeds,
    outds=work.test_results
  )
  libname &lref JSON fileref=&fref;
  %let hasitems=%sysfunc(exist(&lref..items));
  %let hasid=0;
  %let hasdesc=0;
  %if &hasitems %then %do;
    %let hasid=%mf_existvar(&lref..items,id);
    %let hasdesc=%mf_existvar(&lref..items,description);
  %end;
  data work.expectedgroups;
    if 0 then set work.groupmodel;
    %if &hasid %then %do;
      set &lref..items;
      groupuri=id;
      groupname=name;
      %if &hasdesc %then %do;
        groupdesc=description;
      %end;
      keep groupuri groupname groupdesc;
    %end;
    %else %do;
      stop;
    %end;
  run;
  proc sort data=work.expectedgroups;
    by groupuri groupname groupdesc;
  run;
  proc sort data=work.viyagroups out=work.actualgroups;
    by groupuri groupname groupdesc;
  run;
  %let mismatches=0;
  %if %mf_nobs(work.expectedgroups)=0 and
      %mf_nobs(work.actualgroups)=0 %then %do;
    /* PROC COMPARE warns when both inputs are empty. */
  %end;
  %else %do;
    proc compare base=work.expectedgroups compare=work.actualgroups noprint;
    run;
    %let mismatches=&sysinfo;
  %end;
  %mp_assert(iftrue=(&mismatches=0),
    desc=All group IDs names and descriptions match the API,
    outds=work.test_results
  )
  filename &fref clear;
  libname &lref clear;
%mend check_group_values;
%check_group_values()
