/**
  @file
  @brief Testing mp_reseterror

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_reseterror.sas

**/

/* force a failure */

lock sashelp.class;

/* recover ? */
%mp_reseterror()

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking the failure condition was fixed,
  outds=work.test_results
)
