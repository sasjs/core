/**
  @file
  @brief Testing mp_dictionary.sas macro

  <h4> SAS Macros </h4>
  @li mp_dictionary.sas
  @li mp_assert.sas

**/

libname test (work);
%mp_dictionary(lib=test)

proc sql;
create table work.compare1 as select * from test.styles;
create table work.compare2 as select * from dictionary.styles;

proc compare base=compare1 compare=compare2;
run;
%put _all_;

%mp_assert(
  iftrue=(%mf_existds(&sysinfo)=0),
  desc=Compare was exact,
  outds=work.test_results
)
