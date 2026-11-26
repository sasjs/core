/**
  @file
  @brief Testing mp_ds2fmtds.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2fmtds.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

  @sasjslint {"noUnusedMacros": false}
**/

proc sql;
create table test as select * from dictionary.tables where libname='SASHELP';

filename inc temp;
data _null_;
  set work.test;
  file inc;
  libds=cats('sashelp.',memname);
  if exist(libds) then line=cats('%mp_ds2fmtds(',libds,',',memname,')');
  put line;
run;

/* A known fixture exercises formatted character, numeric and date values. */
data work.fmt_input;
  length id $6 label $6 amount when 8;
  format label $char12. amount comma12.2 when yymmdd10.;
  id='A'; label='First'; amount=12.5; when='02JAN2024'd; output;
  id='B'; label='Second'; amount=-3.25; when='31DEC2023'd; output;
run;

%mp_assertscope(SNAPSHOT)
%mp_ds2fmtds(work.fmt_input,work.fmt_output)
%mp_assertscope(COMPARE,
  desc=Formatted dataset conversion does not leak macro variables,
  outds=work.test_results
)

data work.fmt_model;
  length id $6 label $12 amount when $24;
  call missing(id,label,amount,when);
  stop;
run;

%mp_assertmodel(work.fmt_output,base=work.fmt_model,key=id,
  desc=Formatted dataset model and key,
  outds=work.test_results
)

%mp_assertdsobs(work.fmt_output,
  test=EQUALS 2,
  desc=Formatted dataset has both rows,
  outds=work.test_results
)

data work.fmt_bad;
  set work.fmt_output;
  if not ((id='A' and label='First' and amount='12.50'
      and when='2024-01-02')
    or (id='B' and label='Second' and amount='-3.25'
      and when='2023-12-31'));
run;

%mp_assertdsobs(work.fmt_bad,
  test=EQUALS 0,
  desc=Formatted values match the input rows,
  outds=work.test_results
)

options obs=50;
%inc inc;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking tables were created successfully,
  outds=work.test_results
)
