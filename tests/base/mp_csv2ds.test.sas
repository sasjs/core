/**
  @file
  @brief Testing mp_csv2ds macro

  <h4> SAS Macros </h4>
  @li mp_csv2ds.sas
  @li mp_assert.sas

**/

filename csvref temp;

data _null_;
  file csvref;
  put 'id,name,amount';
  put '1,alpha,10';
  put '2,beta,20';
  put '3,gamma,30';
run;

/* the base dataset supplies the variables the CSV is loaded into */
data work.csv_base;
  length id $10 name $20 amount $10;
  call missing(of _all_);
  stop;
run;

%mp_csv2ds(inref=csvref,outds=work.csv_out,baseds=work.csv_base)

proc sql noprint;
  select count(*) into: n_rows from work.csv_out;
  select name into: first_name from work.csv_out(obs=1);
quit;

%mp_assert(
  iftrue=(&n_rows=3),
  desc=Checking that every row of the csv is loaded,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(strip(&first_name))=alpha),
  desc=Checking that the first data row is stored under the header variable,
  outds=work.test_results
)
