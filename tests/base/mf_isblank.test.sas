/**
  @file
  @brief Testing mf_isblank macro

  <h4> SAS Macros </h4>
  @li mf_isblank.sas
  @li mp_assert.sas

**/

%let test_blank=;
%mp_assert(
  iftrue=(%mf_isblank(&test_blank)=1),
  desc=An empty macro variable is blank,
  outds=work.test_results
)

%let test_value=abc;
%mp_assert(
  iftrue=(%mf_isblank(&test_value)=0),
  desc=A populated macro variable is not blank,
  outds=work.test_results
)

%let test_zero=0;
%mp_assert(
  iftrue=(%mf_isblank(&test_zero)=0),
  desc=The digit zero is not blank,
  outds=work.test_results
)
