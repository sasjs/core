/**
  @file
  @brief Creates a dataset with the commit history of a local repository
  @details Returns the commit history from a local repository. The name of the
  branch is also returned.

  More details here:
https://documentation.sas.com/doc/ko/pgmsascdc/v_033/lefunctionsref/n1qo5miyvry1nen111js203hlwrh.htm

  Usage:

      %let gitdir=%sysfunc(pathname(work))/core;
      %let repo=https://github.com/sasjs/core;
      %put source clone rc=%sysfunc(GITFN_CLONE(&repo,&dir));

      %mp_gitlog(&gitdir,outds=work.mp_gitlog)

  @param [in] gitdir The directory containing the GIT repository
  @param [in] filter= (BRANCHONLY) To return only the commits for the current
  branch, use BRANCHONLY (the default).  Anything else will return the entire
  commit history.
  @param [out] outds= (work.mp_gitlog) The output dataset to create.
  All vars are $128 except `message` which is $4000.
    @li author returns the author who submitted the commit.
    @li children_ids returns a list of the children commit IDs
    @li committer returns the name of the committer.
    @li committer_email returns the email of the committer.
    @li email returns the email of the commit author.
    @li id returns the commit ID of the commit object.
    @li in_current_branch returns "TRUE" or "FALSE" to indicate if the commit is
      in the current branch.
    @li message returns the commit message.
    @li parent_ids returns a list of the parent commit IDs.
    @li stash returns "TRUE" or "FALSE" to indicate if the commit is a stash
      commit.
    @li time returns the time of the commit as numeric string
    @li commit_time_num time of the commit as numeric SAS datetime
    @li commit_time_str the commit_time_num variable cast as string

  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [in] nobs= (0) Set to an integer greater than 0 to restrict the number
  of rows returned

  <h4> SAS Macros </h4>
  @li mf_getgitbranch.sas

  <h4> Related Files </h4>
  @li mp_gitadd.sas
  @li mp_gitreleaseinfo.sas
  @li mp_gitstatus.sas

**/

%macro mp_gitlog(gitdir,outds=work.mp_gitlog,mdebug=0,filter=BRANCHONLY,nobs=0);

%local varlist i var;
%let varlist=author children_ids committer committer_email email id
  in_current_branch parent_ids stash time ;

data &outds;
  LENGTH gitdir branch $ 1024 message $4000 &varlist $128 commit_time_num 8.
    commit_time_str $32;
  call missing (of _all_);
  branch="%mf_getgitbranch(&gitdir)";
  gitdir=symget('gitdir');
  rc=git_status_free(trim(gitdir));
  if rc=-1 then do;
    put "The libgit2 library is unavailable and no Git operations can be used.";
    put "See: https://stackoverflow.com/questions/74082874";
    stop;
  end;
  else if rc=-2 then do;
    put "The libgit2 library is available, but the status function failed.";
    put "See the log for details.";
    stop;
  end;
  entries=git_commit_log(trim(gitdir));
  do n=1 to entries;

  %do i=1 %to %sysfunc(countw(&varlist message));
    %let var=%scan(&varlist message,&i,%str( ));
    rc=git_commit_get(n,trim(gitdir),"&var",&var);
  %end;
    /* convert unix time to SAS time - https://4gl.uk/corelink0 */
    /* Number of seconds between 01JAN1960 and 01JAN1970: 315619200 */
    format commit_time_num datetime19.;
    commit_time_num=sum(input(cats(time),best.),315619200);
    commit_time_str=put(commit_time_num,datetime19.);
  %if &mdebug=1 %then %do;
    putlog (_all_)(=);
  %end;
    if "&filter"="BRANCHONLY" then do;
      if cats(in_current_branch)='TRUE' then output;
    end;
    else output;
  %if &nobs>0 %then %do;
    if n ge &nobs then stop;
  %end;
  end;
  rc=git_commit_free(trim(gitdir));
  keep gitdir branch &varlist message time commit_time_num commit_time_str;
run;

%mend mp_gitlog;
