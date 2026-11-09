/**
  @file
  @brief Testing mddl_derivedvars macro

  <h4> SAS Macros </h4>
  @li mddl_derivedvars.sas
  @li mf_existds.sas
  @li mp_assert.sas

**/

%mddl_derivedvars(libds=work.derived_vars)

proc sql noprint;
  select count(*) into: n_cols from dictionary.columns
    where upcase(libname)='WORK' and upcase(memname)='DERIVED_VARS';
  select count(*) into: n_idx from sashelp.vindex
    where upcase(libname)='WORK' and upcase(memname)='DERIVED_VARS'
      and upcase(indxname)='PK_DERIVEDVARS';
quit;

%mp_assert(
  iftrue=(%mf_existds(work.derived_vars)=1),
  desc=Checking that the derived variables table is created,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_cols=10),
  desc=Checking that the table has the ten documented columns,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_idx=3),
  desc=Checking that the three column primary key index is created,
  outds=work.test_results
)
