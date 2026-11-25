/**
  @file
  @brief Testing mp_distinctfmtvalues macro

  <h4> SAS Macros </h4>
  @li mp_distinctfmtvalues.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas

**/

data work.fmtvals;
  dt='01jan2020'd; output;
  dt='01jan2020'd; output;
  dt='02feb2021'd; output;
  dt='03mar2022'd; output;
  format dt date9.;
run;

%mp_distinctfmtvalues(libds=work.fmtvals,var=dt,outds=work.dfv_out)

data work.dfv_model;
  length formatted_value $2000;
  stop;
run;

%mp_assertmodel(work.dfv_out,
  base=work.dfv_model,
  key=formatted_value,
  desc=Checking formatted value model and key,
  outds=work.test_results
)

proc sql noprint;
  select count(*) into: n_vals from work.dfv_out;
  select count(*) into: n_hit from work.dfv_out
    where formatted_value='01JAN2020';
  select count(*) into: n_expected from work.dfv_out
    where formatted_value in ('01JAN2020','02FEB2021','03MAR2022');
quit;

%mp_assert(
  iftrue=(&n_vals=3),
  desc=Checking that duplicate formatted values collapse to one row,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_hit=1),
  desc=Checking that the value carries the variable format,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_expected=3),
  desc=Checking all three formatted dates are present,
  outds=work.test_results
)
