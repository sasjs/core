/**
  @file
  @brief Testing mf_getuniquelibref macro
  @details To test performance you can also use the following macro:

  <h4> SAS Macros </h4>
  @li mf_getuniquelibref.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* check valid libs */
%mp_assertscope(SNAPSHOT)
%let libshort=%mf_getuniquelibref(prefix=lib);
%mp_assertscope(COMPARE,ignorelist=LIBSHORT)
libname &libshort (work);
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking for valid libref &libshort,
  outds=work.test_results
)

%let lib7=%mf_getuniquelibref(prefix=libref7);
libname &lib7 (work);
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking for valid libref &lib7,
  outds=work.test_results
)


/* check for invalid libs */

%let lib8=%mf_getuniquelibref(prefix=lib8char);
%mp_assert(
  iftrue=(&lib8=0),
  desc=Invalid prefix (8 chars),
  outds=work.test_results
)

%let liblong=%mf_getuniquelibref(prefix=invalidlib);
%mp_assert(
  iftrue=(&liblong=0),
  desc=Checking for invalid libref (long),
  outds=work.test_results
)

%let badlib=%mf_getuniquelibref(prefix=8adlib);
%mp_assert(
  iftrue=(&badlib=0),
  desc=Checking for invalid libref (8adlib),
  outds=work.test_results
)