/**
  @file
  @brief Testing mp_ds2md.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2md.sas
  @li mp_assert.sas

**/

%mp_ds2md(sashelp.class,outref=md)

data _null_;
  infile md;
  input;
  call symputx(cats('test',_n_),_infile_);
  if _n_=4 then stop;
run;

%mp_assert(
  iftrue=("&test1"="|NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|"),
  desc=Checking header row,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test2"="|---|---|---|---|---|"),
  desc=Checking divider row,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test3"="|`Alfred `|`M `|`14 `|`69 `|`112.5 `|"),
  desc=Checking data row,
  outds=work.test_results
)