/**
  @file
  @brief Testing mp_gitstatus.sas macro

  <h4> SAS Macros </h4>
  @li mf_deletefile.sas
  @li mf_writefile.sas
  @li mp_gitstatus.sas
  @li mp_assertdsobs.sas

**/

/* clone the source repo */
%let dir = %sysfunc(pathname(work))/core;
%put source clone rc=%sysfunc(GITFN_CLONE(https://github.com/sasjs/core,&dir));

%mp_gitstatus(&dir,outds=work.gitstatus)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Initial mp_gitstatus runs without errors,
  outds=work.test_results
)

/* should be empty as there are no changes yet */
%mp_assertdsobs(work.gitstatus,test=EMPTY)

/* add a file */
%mf_writefile(&dir/somefile.txt,l1=some content)
/* change a file */
%mf_writefile(&dir/readme.md,l1=new readme)
/* delete a file */
%mf_deletefile(&dir/package.json)

/* re-run git status */
%mp_gitstatus(&dir,outds=work.gitstatus)

/* should be three changes now */
%mp_assertdsobs(work.gitstatus,test=EQUALS 3)
