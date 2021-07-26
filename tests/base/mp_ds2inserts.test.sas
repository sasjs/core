/**
  @file
  @brief Testing mp_ds2inserts.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2inserts.sas
  @li mp_assert.sas

**/

/**
  * test 1 - rebuild an existing dataset
  * Cars is a great dataset - it contains leading spaces, and formatted numerics
  */

%mp_ds2inserts(sashelp.cars,outref=testref,outlib=work,outds=test)

data work.test;
  set sashelp.cars;
  stop;
proc sql;
%inc testref;

proc compare base=sashelp.cars compare=work.test;
quit;

%mp_assert(
  iftrue=(&sysinfo=1),
  desc=sashelp.cars is identical except for ds label,
  outds=work.test_results
)