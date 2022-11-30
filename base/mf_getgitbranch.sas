/**
  @file
  @brief Retrieves the current branch from a local GIT repo
  @details In a local git repository, the current branch is always available in
  the `.git/HEAD` file in a format like this:  `ref: refs/heads/master`

  This macro simply reads the file and returns the last word (eg `master`).

  Example usage:

      %let gitdir=%sysfunc(pathname(work))/core;
      %let repo=https://github.com/sasjs/core;
      %put source clone rc=%sysfunc(GITFN_CLONE(&repo,&gitdir));

      %put The current branch is %mf_getgitbranch(&gitdir);

  @param [in] gitdir The directory containing the GIT repository

  <h4> SAS Macros </h4>
  @li mf_readfile.sas

  <h4> Related Macros </h4>
  @li mp_gitadd.sas
  @li mp_gitlog.sas
  @li mp_gitreleaseinfo.sas
  @li mp_gitstatus.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getgitbranch(gitdir
)/*/STORE SOURCE*/;

  %scan(%mf_readfile(&gitdir/.git/HEAD),-1)

%mend mf_getgitbranch;
