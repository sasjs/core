/**
  @file
  @brief Creates a dataset with the output from `GIT_STATUS()`
  @details Uses `git_status()` to fetch the number of changed files, then
  iterates through with `git_status_get()` and `git_index_add()` for each
  change - which is created in an output dataset.

  Usage:

      %let dir=%sysfunc(pathname(work))/core;
      %let repo=https://github.com/sasjs/core;
      %put source clone rc=%sysfunc(GITFN_CLONE(&repo,&dir));
      %mf_writefile(&dir/somefile.txt,l1=some content)
      %mf_deletefile(&dir/package.json)

      %mp_gitstatus(&dir,outds=work.gitstatus)

  More info on these functions is in this [helpful paper](
https://www.sas.com/content/dam/SAS/support/en/sas-global-forum-proceedings/2019/3057-2019.pdf
  ) by Danny Zimmerman.

  @param [in] gitdir The directory containing the GIT repository
  @param [out] outds= (work.git_status) The output dataset to create.  Vars:
    @li gitdir $1024 - directory of repo
    @li path $1024 - relative path to the file in the repo
    @li staged $32 - whether the file is staged (TRUE or FALSE)
    @li status $64 - either new, deleted, or modified
    @li cnt - number of files
    @li n - the "nth" file in the list from git_status()

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> Related Files </h4>
  @li mp_gitstatus.test.sas
  @li mp_gitadd.sas

**/

%macro mp_gitstatus(gitdir,outds=work.mp_gitstatus,mdebug=0);

data &outds;
  LENGTH gitdir path $ 1024 STATUS $ 64 STAGED $ 32;
  call missing (of _all_);
  gitdir=symget('gitdir');
  cnt=git_status(trim(gitdir));
  if cnt=-1 then do;
    put "The libgit2 library is unavailable and no Git operations can be used.";
    put "See: https://stackoverflow.com/questions/74082874";
  end;
  else if cnt=-2 then do;
    put "The libgit2 library is available, but the status function failed.";
    put "See the log for details.";
  end;
  else do n=1 to cnt;
    rc=GIT_STATUS_GET(n,gitdir,'PATH',path);
    rc=GIT_STATUS_GET(n,gitdir,'STAGED',staged);
    rc=GIT_STATUS_GET(n,gitdir,'STATUS',status);
    output;
  %if &mdebug=1 %then %do;
    putlog (_all_)(=);
  %end;
  end;
  rc=git_status_free(gitdir);
  drop rc cnt;
run;

%mend mp_gitstatus;
