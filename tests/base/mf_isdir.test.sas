/**
  @file
  @brief Testing mf_isdir macro

  <h4> SAS Macros </h4>
  @li mf_isdir.sas
  @li mp_assert.sas

**/

%let workdir=%sysfunc(pathname(work));

%mp_assert(
  iftrue=(%mf_isdir(&workdir)=1),
  desc=The session work folder is a directory,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_isdir(&workdir/no_such_folder_here)=0),
  desc=A path that does not exist is not a directory,
  outds=work.test_results
)
