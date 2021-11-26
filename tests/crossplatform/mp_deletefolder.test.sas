/**
  @file
  @brief Testing mp_deletefolder.sas macro

  <h4> SAS Macros </h4>
  @li mp_deletefolder.sas
  @li mf_mkdir.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_dirlist.sas

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
  desc=Temp data successfully created,
  outds=work.test_results
)

%mp_deletefolder(&root/a)

%mp_dirlist(path=&root, outds=work.myTable2, maxdepth=MAX)

data _null_;
  set work.mytable2;
  putlog (_all_)(=);
run;

%mp_assert(
  iftrue=(%mf_nobs(work.mytable2)=1),
  desc=Subfolder and contents successfully deleted,
  outds=work.test_results
)
