/**
  @file
  @brief Testing mf_getkeyvalue macro

  <h4> SAS Macros </h4>
  @li mf_getkeyvalue.sas
  @li mp_setkeyvalue.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_setkeyvalue(provnum,22,type=N)
%mp_setkeyvalue(provchar,somevalue,type=C)

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getkeyvalue(provnum);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getkeyvalue does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getkeyvalue(provnum)=22),
  desc=Checking that a numeric value is returned for a numeric key,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(strip(%mf_getkeyvalue(provchar)))=somevalue),
  desc=Checking that a character value is returned for a character key,
  outds=work.test_results
)
