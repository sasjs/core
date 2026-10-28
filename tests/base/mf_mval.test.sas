/**
  @file
  @brief Testing mf_mval macro

  <h4> SAS Macros </h4>
  @li mf_mval.sas
  @li mp_assert.sas

**/

%let existing_var=itdid;
%let blank_var=;

%mp_assert(
  iftrue=(%mf_mval(existing_var)=itdid),
  desc=An existing macro variable returns its value,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_mval(blank_var))=0),
  desc=A blank macro variable returns nothing,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%length(%mf_mval(never_set_var))=0),
  desc=An undefined macro variable returns nothing,
  outds=work.test_results
)
