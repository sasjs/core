/**
  @file
  @brief Testing mp_copyfolder.sas macro

  <h4> SAS Macros </h4>
  @li mp_copyfolder.sas
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
data "&root/a/e/f/ds1.sas7bdat";x=1;
data "&root/a/e/ds2.sas7bdat";x=1;
data "&root/a/ds3.sas7bdat";x=1;
run;

%mp_dirlist(path=&root, outds=myTable, maxdepth=MAX)

%mp_assert(
  iftrue=(%mf_nobs(work.mytable)=8),
  desc=Temp data successfully created,
  outds=work.test_results
)

/**
  * copy it
  */
%let newfolder=%sysfunc(pathname(work))/new;
%mp_copyfolder(&root,&newfolder)

%mp_dirlist(path=&newfolder, outds=work.myTable2, maxdepth=MAX)

%mp_assert(
  iftrue=(%mf_nobs(work.mytable2)=8),
  desc=Folder successfully copied,
  outds=work.test_results
)


