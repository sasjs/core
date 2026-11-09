/**
  @file
  @brief Testing mf_getxengine macro

  <h4> SAS Macros </h4>
  @li mf_getxengine.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

filename feng temp;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getxengine(feng);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getxengine does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getxengine(feng)=TEMP),
  desc=Checking that a temporary fileref reports the TEMP engine,
  outds=work.test_results
)

/* the macro documentation says a missing fileref returns 0 - it returns a
  blank, because the row exists in SASHELP.VEXTFL with an empty XENGINE */
%mp_assert(
  iftrue=(%length(%mf_getxengine(nosuchfref))=0),
  desc=Checking that a fileref that is not assigned returns nothing,
  outds=work.test_results
)
