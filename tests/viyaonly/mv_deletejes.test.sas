/**
  @file
  @brief Testing mv_deletejes macro

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_deletejes.sas

**/

%let path=&mcTestAppLoc/jobs;
%let name=deletejob;

filename ft15f001 temp;
data _null_;
  file ft15f001;
  put 'data _null_; run;';
run;
%mv_createjob(path=&path, name=&name)

%mp_assertscope(SNAPSHOT)
%mv_deletejes(path=&path, name=&name)
%mp_assertscope(COMPARE,
  desc=mv_deletejes does not leak scope,
    ignorelist=MC6_JADP1LEN MC6_JADP2LEN MC6_JADP3LEN MC6_JADPNUM MC6_JADVLEN,
  outds=work.test_results
)

/* the folder listing is not usable as the oracle here - it errors on a folder
  this macro has just emptied - so the definition is looked up directly */
%let base_uri=%mf_getplatform(VIYARESTAPI);
%let fname=%mf_getuniquefileref();
proc http method='GET' out=&fname oauth_bearer=sas_services
  url="&base_uri/folders/folders/@item?path=&path/&name";
run;
%mp_assert(
  iftrue=(&SYS_PROCHTTP_STATUS_CODE=404),
  desc=Check the job definition is gone
)
