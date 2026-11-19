/**
  @file
  @brief Test a failed root folder request is not returned as an empty listing
  @details The invalid bearer token must fail before an output table is made.
    The abort override records the outcome and terminates this test session.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mv_getfoldermembers.sas

**/

%macro mp_abort(iftrue=,mac=,msg=);
  %if not(%eval(%unquote(&iftrue))) %then %return;
  %mp_assert(
    iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200),
    desc=The root folder request failed,
    outds=work.test_results
  )
  %mp_assert(
    iftrue=(%sysfunc(exist(work.failedroot))=0),
    desc=The failed root request did not create an empty listing,
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

%let invalid_folder_token=invalid-token;
%mv_getfoldermembers(root=/,grant_type=authorization_code,
  access_token_var=invalid_folder_token,outds=work.failedroot)

%mp_assert(
  iftrue=(0=1),
  desc=The failed root folder request must abort,
  outds=work.test_results
)
