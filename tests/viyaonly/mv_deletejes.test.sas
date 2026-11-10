/**
  @file
  @brief Testing mv_deletejes macro

  <h4> SAS Macros </h4>
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

/* the listing is the oracle, and it also covers the empty-folder path.  The
  assertion is scoped to this job's name rather than the row count, so it says
  nothing about anything else that lands in the folder */
%mv_getfoldermembers(root=&path, outds=work.afterdelete)
%let stillthere=0;
data _null_;
  set work.afterdelete;
  if upcase(name)=upcase("&name") then call symputx('stillthere',1,'l');
run;
%mp_assert(
  iftrue=(&stillthere=0),
  desc=Check the job definition is gone
)
