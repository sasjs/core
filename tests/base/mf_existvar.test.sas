/**
  @file
  @brief Testing mf_existvar macro

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mp_assert.sas

**/


%mp_assert(
  iftrue=(%mf_existvar(sashelp.class,age)>0),
  desc=Checking existing var exists
)

%mp_assert(
  iftrue=(%mf_existvar(sashelp.class,isjustanumber)=0),
  desc=Checking non existing var does not exist
)

data work.lockcheck;
  a=1;
  output;
  stop;
run;

%mp_assert(
  iftrue=(%mf_existvar(work.lockcheck,)=0),
  desc=Checking non-provided var does not exist
)

proc sql;
update work.lockcheck set a=2;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking the lock was released,
  outds=work.test_results
)