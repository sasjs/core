/**
  @file
  @brief Testing mp_applyformats.sas macro

  <h4> SAS Macros </h4>
  @li mf_getvarformat.sas
  @li mp_applyformats.sas
  @li mp_assert.sas
  @li mp_getcols.sas

**/

/**
  * Test 1 Base case
  */

data work.example;
  set sashelp.prdsale;
  format _all_;
run;
%let origfmt=%mf_getvarformat(work.example,month);

%mp_getcols(sashelp.prdsale,outds=work.cols)

data work.cols2;
  set work.cols;
  lib='WORK';
  ds='EXAMPLE';
  var=name;
  fmt=format;
  keep lib ds var fmt;
run;

%mp_applyformats(work.cols2)

%mp_assert(
  iftrue=("&origfmt"=""),
  desc=Check that formats were cleared,
  outds=work.test_results
)
%mp_assert(
  iftrue=("%mf_getvarformat(work.example,month)"="MONNAME3."),
  desc=Check that formats were applied,
  outds=work.test_results
)