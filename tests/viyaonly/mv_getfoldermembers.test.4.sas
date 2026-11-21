/**
  @file
  @brief Test a failed folder lookup is not returned as an empty listing
  @details A nonexistent path must fail before an output table is made.
    The abort override records the outcome and terminates this test session.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li mv_getfoldermembers.sas

**/

%macro mp_abort(iftrue=,mac=,msg=);
  %if not(%eval(%unquote(&iftrue))) %then %return;
  %mp_assert(
    iftrue=(&SYS_PROCHTTP_STATUS_CODE=404),
    desc=The nonexistent folder lookup returns 404,
    outds=work.test_results
  )
  %mp_assert(
    iftrue=(%sysfunc(exist(work.failedlookup))=0),
    desc=The failed lookup did not create an empty listing,
    outds=work.test_results
  )
  %webout(OPEN)
  %webout(OBJ,TEST_RESULTS)
  %webout(CLOSE)
  %let syscc=0;
  data _null_;
    abort cancel nolist;
  run;
%mend mp_abort;

%let missingfolder=%mf_getuniquename();
%mv_getfoldermembers(root=&mcTestAppLoc/&missingfolder,
  outds=work.failedlookup)

%mp_assert(
  iftrue=(0=1),
  desc=The failed folder lookup must abort,
  outds=work.test_results
)
