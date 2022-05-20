/**
  @file
  @brief Testing mp_reseterror macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_reseterror.sas

**/


/* cause an error */

lock sashelp.class;

/* recover ? */
%mp_reseterror()

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking error condition was fixed,
  outds=work.test_results
)
