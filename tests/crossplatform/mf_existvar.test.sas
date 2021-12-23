/**
  @file
  @brief Testing mf_existvar macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mp_assert.sas

**/


%mp_assert(
  iftrue=(%mf_existvar(sashelp.class,age)=1),
  desc=Checking existing var exists,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existvar(sashelp.class,isjustanumber)=0),
  desc=Checking non existing var does not exist,
  outds=work.test_results
)