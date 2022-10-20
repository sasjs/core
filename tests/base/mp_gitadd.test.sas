/**
  @file
  @brief Testing mp_gitadd.sas macro

  <h4> SAS Macros </h4>
  @li mf_deletefile.sas
  @li mf_writefile.sas
  @li mp_gitadd.sas
  @li mp_gitstatus.sas
  @li mp_assert.sas

**/

/* clone the source repo */
%let dir = %sysfunc(pathname(work))/core;
%put source clone rc=%sysfunc(GITFN_CLONE(https://github.com/sasjs/core,&dir));

/* add a file */
%mf_writefile(&dir/somefile.txt,l1=some content)
/* change a file */
%mf_writefile(&dir/readme.md,l1=new readme)
/* delete a file */
%mf_deletefile(&dir/package.json)

/* Run git status */
%mp_gitstatus(&dir,outds=work.gitstatus)

%let test1=0;
proc sql noprint;
select count(*) into: test1 from work.gitstatus where staged='FALSE';

/* should be three unstaged changes now */
%mp_assert(
  iftrue=(&test1=3),
  desc=3 changes are ready to add,
  outds=work.test_results
)

/* add them */
%mp_gitadd(&dir,inds=work.gitstatus,mdebug=&sasjs_mdebug)

/* check status */
%mp_gitstatus(&dir,outds=work.gitstatus2)
%let test2=0;
proc sql noprint;
select count(*) into: test2 from work.gitstatus2 where staged='TRUE';

/* should be three staged changes now */
%mp_assert(
  iftrue=(&test2=3),
  desc=3 changes were added,
  outds=work.test_results
)
