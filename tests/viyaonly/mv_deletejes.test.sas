/**
  @file
  @brief Testing mv_deletejes macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_deletejes.sas
  @li mv_getfoldermembers.sas

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

/* the listing is the oracle, and it also covers the empty-folder path: the
  folder is empty once the delete has run */
%mv_getfoldermembers(root=&path, outds=work.afterdelete)
%mp_assert(
  iftrue=(%mf_nobs(work.afterdelete)=0),
  desc=Check the job definition is gone
)
