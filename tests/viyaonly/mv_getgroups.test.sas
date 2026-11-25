/**
  @file
  @brief Testing mv_getgroups macro

  <h4> SAS Macros </h4>
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

data work.groupmodel;
  length groupuri groupname groupdesc $256;
  stop;
run;

/* The JSON engine publishes these globals for the first JSON libref. */
%mp_assertscope(SNAPSHOT)
%mv_getgroups(outds=work.viyagroups)
%mp_assertscope(COMPARE,
  desc=mv_getgroups does not leak scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN,
  outds=work.test_results
)
%mp_assertmodel(work.viyagroups,base=work.groupmodel,key=groupuri,
  desc=Groups have the exact model and unique nonmissing identifiers,
  outds=work.test_results
)
%mp_assert(iftrue=(%mf_nobs(work.viyagroups)>0),
  desc=Groups contain rows,
  outds=work.test_results
)

/* Independently retrieve the same resource to verify all rows and values. */
%macro check_group_values();
  %local base_uri fref lref hasdesc mismatches;
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
  %let hasdesc=%mf_existvar(&lref..items,description);
  data work.expectedgroups;
    length groupuri groupname groupdesc $256;
    set &lref..items;
    groupuri=id;
    groupname=name;
    %if &hasdesc %then %do;
      groupdesc=description;
    %end;
    keep groupuri groupname groupdesc;
  run;
  proc sort data=work.expectedgroups;
    by groupuri groupname groupdesc;
  run;
  proc sort data=work.viyagroups out=work.actualgroups;
    by groupuri groupname groupdesc;
  run;
  proc compare base=work.expectedgroups compare=work.actualgroups noprint;
  run;
  %let mismatches=&sysinfo;
  %mp_assert(iftrue=(&mismatches=0),
    desc=All group IDs names and descriptions match the API,
    outds=work.test_results
  )
  filename &fref clear;
  libname &lref clear;
%mend check_group_values;
%check_group_values()
