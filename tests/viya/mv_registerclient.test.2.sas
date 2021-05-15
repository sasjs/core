/**

  @file
  @brief Testing mv_registerclient.sas macro
  @details Tests for unsuccessful registration.  To do this, overrides are
  applied for the mf_loc.sas and mp_abort.sas macros.
​
  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mv_registerclient.sas

**/

/**
  * Test Case
  */

%macro mf_loc(param);
  /does/not/exist
%mend mf_loc;

%macro mp_abort(iftrue=,mac=mp_abort.sas, type=, msg=);
  %if not(%eval(%unquote(&iftrue))) %then %return;
  %put %substr(&msg,1,16);
  %mp_assert(
    iftrue=("%substr(&msg,1,16)"="Unable to access"),
    desc=Check that abort happens when consul token is unavailable
  )
  %webout(OPEN)
  %webout(OBJ, TEST_RESULTS)
  %webout(CLOSE)
  %let syscc=0;
  data _null_;
    abort cancel nolist;
  run;
%mend mp_abort;

%mv_registerclient( outds=testds)

%mp_assert(
  iftrue=(0=1),
  desc=Check that abort happens when consul token is unavailable
)