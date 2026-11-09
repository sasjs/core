/**
  @file
  @brief Testing mf_getplatform macro

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getplatform();
%mp_assertscope(COMPARE,
  desc=Checking that mf_getplatform does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%index(SASMETA SASVIYA SASJS BASESAS,%mf_getplatform())>0),
  desc=Checking that one of the four documented platforms is returned,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_getplatform())>0),
  desc=Checking that a platform is always returned,
  outds=work.test_results
)

/* the harness never runs inside a SAS Studio client */
%mp_assert(
  iftrue=(%mf_getplatform(switch=SASSTUDIO)=0),
  desc=Checking that a non SAS Studio client reports version 0,
  outds=work.test_results
)

%if %mf_getplatform() ne SASVIYA %then %do;
  %mp_assert(
    iftrue=(%length(%mf_getplatform(switch=VIYARESTAPI))=0),
    desc=Checking that the Viya REST switch is empty away from Viya,
    outds=work.test_results
  )
%end;
