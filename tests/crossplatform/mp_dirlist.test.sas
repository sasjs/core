/**
  @file
  @brief Testing mp_ds2cards.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mf_mkdir.sas
  @li mp_dirlist.sas
  @li mp_assert.sas

**/

/**
  * make a directory structure
  */

%let root=%sysfunc(pathname(work))/top;
%mf_mkdir(&root)
%mf_mkdir(&root/a)
%mf_mkdir(&root/b)
%mf_mkdir(&root/a/d)
%mf_mkdir(&root/a/e)
%mf_mkdir(&root/a/e/f)
data "&root/a/e/f/ds1.sas7bdat";
  x=1;
run;

%mp_dirlist(path=&root, outds=myTable, maxdepth=MAX)

%mp_assert(
  iftrue=(%mf_nobs(work.mytable)=6),
  desc=All levels returned,
  outds=work.test_results
)

%mp_dirlist(path=&root, outds=myTable2, maxdepth=2)

%mp_assert(
  iftrue=(%mf_nobs(work.mytable2)=5),
  desc=Top two levels returned,
  outds=work.test_results
)

%mp_dirlist(path=&root, outds=myTable3, maxdepth=0)

%mp_assert(
  iftrue=(%mf_nobs(work.mytable3)=2),
  desc=Top level returned,
  outds=work.test_results
)