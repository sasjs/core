/**
  @file
  @brief Testing mv_getfoldermembers macro with nothing to list
  @details A root with no members to return must still produce the documented
    dataset, so a caller can read its columns and a later step is not left with
    a dirty syscc. Two shapes are covered: a folder that exists and is empty
    (the answer carries no items dataset) and a root whose answer carries no
    members link at all.

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas
  @li mv_createfolder.sas
  @li mv_createjob.sas
  @li mv_getfoldermembers.sas

**/

%let folder=&mcTestAppLoc/foldermembers;
%let job=amember;

%mv_createfolder(path=&folder)

/* an empty folder - the members answer carries no member columns */
%mp_assertscope(SNAPSHOT)
%mv_getfoldermembers(root=&folder, outds=work.emptylist)
%mp_assertscope(COMPARE,
  desc=mv_getfoldermembers does not leak scope on an empty folder,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
    MC2_JADP1LEN MC2_JADP2LEN MC2_JADP3LEN MC2_JADPNUM MC2_JADVLEN,
  outds=work.test_results
)

%mp_assertdsobs(work.emptylist,
  desc=Check the empty folder returns no rows,
  test=EMPTY,
  outds=work.test_results
)

%let emptycols=%mf_existvar(work.emptylist,createdBy);
%mp_assert(
  iftrue=(&emptycols>0),
  desc=Check the empty listing carries the documented createdBy column
)

/* a member path is not a folder, so its answer carries no members link */
filename ft15f001 temp;
data _null_;
  file ft15f001;
  put 'data _null_; run;';
run;
%mv_createjob(path=&folder, name=&job)

%mp_assertscope(SNAPSHOT)
%mv_getfoldermembers(root=&folder/&job, outds=work.nolink)
%mp_assertscope(COMPARE,
  desc=mv_getfoldermembers does not leak scope without a members link,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN,
  outds=work.test_results
)

%mp_assertdsobs(work.nolink,
  desc=Check a root without a members link returns no rows,
  test=EMPTY,
  outds=work.test_results
)

%let nolinkcols=%mf_existvar(work.nolink,added);
%mp_assert(
  iftrue=(&nolinkcols>0),
  desc=Check the no-link listing carries the documented added column
)

%let sysccatend=&syscc;
%mp_assert(
  iftrue=(&sysccatend=0),
  desc=Check the empty paths leave syscc clean
)
