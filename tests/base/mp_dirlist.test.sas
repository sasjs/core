/**
  @file
  @brief Testing mp_dirlist.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mf_mkdir.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_assertmodel.sas
  @li mddl_dirlist.sas
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
libname test "&root/a/e/f";
data test.ds1;
  x=1;
run;

%mddl_dirlist(work.dirlist_schema)
/* The helper uses underscore plus seven digits; ignore SAS internal # refs. */
proc sql;
  create table work.dirlist_refs_before as
    select distinct fileref from dictionary.extfiles
    where substr(fileref,1,1)='_' and lengthn(fileref)=8
      and verify(substr(fileref,2),'0123456789')=0;
quit;
%mp_assertscope(SNAPSHOT)
%mp_dirlist(path=&root, outds=myTable, maxdepth=MAX)
proc sql;
  create table work.dirlist_refs_after as
    select distinct fileref from dictionary.extfiles
    where substr(fileref,1,1)='_' and lengthn(fileref)=8
      and verify(substr(fileref,2),'0123456789')=0;
quit;
%mp_assertscope(COMPARE,
  desc=Test 1: mp_dirlist does not leak scope,
  outds=work.test_results
)
proc sql noprint;
  select count(*) into :dirlist_newrefs trimmed
    from work.dirlist_refs_after
    where fileref not in (select fileref from work.dirlist_refs_before);
quit;
%mp_assert(iftrue=(&dirlist_newrefs=0),
  desc=Directory listing releases its temporary filerefs)

%mp_assertmodel(work.mytable,base=work.dirlist_schema,
  desc=Populated output matches directory model)

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

%mp_dirlist(path=&root, outds=work.myTable3, maxdepth=0)

%mp_assert(
  iftrue=(%mf_nobs(work.mytable3)=2),
  desc=Top level returned,
  outds=work.test_results
)

%mp_dirlist(path=&root/b, outds=work.myTable4)
%mp_assertmodel(work.mytable4,base=work.dirlist_schema,
  desc=Empty output matches directory model)
%mp_assert(
  iftrue=(%mf_nobs(work.mytable4)=0),
  desc=Empty table for empty directory,
  outds=work.test_results
)

%mp_dirlist(path=&root/notexisting, outds=work.myTable5)
%mp_assert(
  iftrue=(%mf_nobs(work.mytable5)=0),
  desc=Empty table for non-existing directory,
  outds=work.test_results
)

/**
  * maxobs caps the rows returned, and the scan stops at the cap
  */
%mp_dirlist(path=&root, outds=work.myTable6, maxdepth=MAX, maxobs=3)
%mp_assert(
  iftrue=(%mf_nobs(work.mytable6)=3),
  desc=Rows are capped by maxobs,
  outds=work.test_results
)

%mp_dirlist(path=&root, outds=work.myTable7, maxdepth=MAX, maxobs=100)
%mp_assert(
  iftrue=(%mf_nobs(work.mytable7)=6),
  desc=A maxobs above the tree size returns everything,
  outds=work.test_results
)

/**
  * showparent adds the starting folder itself
  */
%mp_dirlist(path=&root, outds=work.myTable8, maxdepth=0, showparent=YES)
%mp_assert(
  iftrue=(%mf_nobs(work.mytable8)=3),
  desc=Showparent adds one row for the parent,
  outds=work.test_results
)

/**
  * the level column reports depth below the parent
  */
data _null_;
  set work.mytable end=eof;
  retain maxlevel 0;
  if level>maxlevel then maxlevel=level;
  if eof then call symputx('maxlevel',maxlevel,'l');
run;
%mp_assert(
  iftrue=(&maxlevel=3),
  desc=Deepest entry is three levels below the parent,
  outds=work.test_results
)

/**
  * a file is reported as a file and a folder as a folder
  */
data _null_;
  set work.mytable;
  if filename='a' then call symputx('type_a',file_or_folder,'l');
  if filename='ds1.sas7bdat' then call symputx('type_ds1',file_or_folder,'l');
run;
%mp_assert(
  iftrue=("%upcase(&type_a)"="FOLDER"),
  desc=A directory entry is classified as a folder,
  outds=work.test_results
)
%mp_assert(
  iftrue=("%upcase(&type_ds1)"="FILE"),
  desc=A dataset file is classified as a file,
  outds=work.test_results
)


/**
  * a blank path is the platform roots - drives on Windows, / on Unix
  */
%mp_dirlist(path=, outds=work.myTable9)
%mp_assert(
  iftrue=(%mf_nobs(work.mytable9)>=1),
  desc=A blank path returns the platform roots,
  outds=work.test_results
)
data _null_;
  set work.mytable9(obs=1);
  call symputx('rootpath',filepath,'l');
run;
%mp_assert(
  iftrue=(%length(&rootpath)>=1),
  desc=The root entry carries a path,
  outds=work.test_results
)

/**
  * a plain file is a file.  Some platforms answer dopen on a file with an
  * empty sysmsg(), so the message checks alone cannot tell it from an entry
  * that could not be opened at all
  */
data _null_;
  file "&root/plain.txt";
  put 'x';
run;
%mp_dirlist(path=&root, outds=work.myTable10)
data _null_;
  set work.mytable10(where=(filename='plain.txt'));
  call symputx('type_txt',file_or_folder,'l');
  call symputx('msg_txt',msg,'l');
run;
%mp_assert(
  iftrue=("%upcase(&type_txt)"="FILE"),
  desc=A text file is classified as a file,
  outds=work.test_results
)

/**
  * dump results to the log for offline inspection
  */
data _null_;
  set work.test_results;
  putlog 'TEST_RESULT_LINE: ' test_result ' - ' test_description;
run;
