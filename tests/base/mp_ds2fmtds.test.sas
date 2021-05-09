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
  line=cats('%mp_ds2fmtds(sashelp.',memname,',',memname,')');
  put line;
run;

%inc inc;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking tables were created successfully,
  outds=work.test_results
)