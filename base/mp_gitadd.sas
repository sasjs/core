/**
  @file
  @brief Stages files in a GIT repo
  @details Uses the output dataset from mp_gitstatus.sas to determine the files
  that should be staged.

  If STAGED != `"TRUE"` then the file is staged (so you could provide an empty
  char column if staging all observations).

  Usage:

      %let dir=%sysfunc(pathname(work))/core;
      %let repo=https://github.com/sasjs/core;
      %put source clone rc=%sysfunc(GITFN_CLONE(&repo,&dir));
      %mf_writefile(&dir/somefile.txt,l1=some content)
      %mf_deletefile(&dir/package.json)
      %mp_gitstatus(&dir,outds=work.gitstatus)

      %mp_gitadd(&dir,inds=work.gitstatus)

  @param [in] gitdir The directory containing the GIT repository
  @param [in] inds= (work.mp_gitadd) The input dataset with the list of files
  to stage.  Will accept the output from mp_gitstatus(), else just use a table
  with the following columns:
    @li path $1024 - relative path to the file in the repo
    @li staged $32 - whether the file is staged (TRUE or FALSE)
    @li status $64 - either new, deleted, or modified

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> Related Files </h4>
  @li mp_gitadd.test.sas
  @li mp_gitstatus.sas

**/

%macro mp_gitadd(gitdir,inds=work.mp_gitadd,mdebug=0);

data _null_;
  set &inds;
  if STAGED ne "TRUE";
  rc=git_index_add("&gitdir",cats(path),status);
  if rc ne 0 or &mdebug=1 then put rc=;
run;

%mend mp_gitadd;
