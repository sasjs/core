/**
  @file
  @brief Testing mp_ds2fmtds.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2fmtds.sas
  @li mp_assert.sas

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

options obs=50;
%inc inc;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking tables were created successfully,
  outds=work.test_results
)