/**
  @file
  @brief Testing mp_deletefolder.sas macro

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mf_nobs.sas
  @li mp_deletefolder.sas
  @li mp_dirlist.sas
  @li mp_assert.sas

**/

/**
  * TEST 1
  */
/* create a folder */

%let work=%sysfunc(pathname(work));
%let deldir=&work/delme;

data "&deldir/something.sas7bdat";
run;

%mp_deletefolder(&deldir)

%mp_dirlist(path=&deldir,outds=isempty)

%mp_assert(
  iftrue=(%mf_nobs(work.isempty)=0),
  desc=Check that deleted directory is empty,
  outds=work.test_results
)

