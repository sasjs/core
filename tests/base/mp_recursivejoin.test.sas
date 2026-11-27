/**
  @file
  @brief Testing mp_recursivejoin macro

  <h4> SAS Macros </h4>
  @li mp_recursivejoin.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

%let recursive_saved_obs=%sysfunc(getoption(obs,keyword));
%let recursive_saved_firstobs=%sysfunc(getoption(firstobs,keyword));
options obs=max firstobs=1;

data work.have;
  p=1;c=2;output;
  p=2;c=3;output;
  p=2;c=4;output;
  p=3;c=5;output;
  p=6;c=7;output;
  p=8;c=9;output;
run;

%mp_assertscope(SNAPSHOT)
%mp_recursivejoin(base_ds=work.have,outds=work.want,matchval=1
  ,parentvar=p,childvar=c)
%mp_assertscope(COMPARE,
  desc=Checking mp_recursivejoin recursive call does not leak scope,
  outds=work.test_results
)

data work.join_model;
  length level p c 8;
  call missing(level,p,c);
  stop;
run;

%mp_assertmodel(work.want,base=work.join_model,
  desc=Checking mp_recursivejoin output model,
  outds=work.test_results
)

proc sql noprint;
  select count(*) into: n_pairs from work.want
    where (p=1 and c=2) or (p=2 and c=3) or (p=2 and c=4) or (p=3 and c=5);
  select count(*) into: n_deep from work.want where c=5;
  select count(*),
    coalesce(sum(level=0 and p=1 and c=2),0),
    coalesce(sum(level=1 and p=2 and c=3),0),
    coalesce(sum(level=1 and p=2 and c=4),0),
    coalesce(sum(level=2 and p=3 and c=5),0),
    coalesce(sum(level=2 and p=4 and c=.),0),
    coalesce(sum(level=3 and p=5 and c=.),0)
    into :n_total, :n_root, :n_23, :n_24, :n_35, :n_leaf4, :n_leaf5
    from work.want;
quit;

%mp_assert(
  iftrue=(&n_pairs=4),
  desc=Checking that every descendant of the parent is returned,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_deep=1),
  desc=Checking that the deepest child is reached,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_total=6 and &n_root=1 and &n_23=1 and &n_24=1
    and &n_35=1 and &n_leaf4=1 and &n_leaf5=1),
  desc=Checking exact mp_recursivejoin rows levels and leaves,
  outds=work.test_results
)

options &recursive_saved_obs &recursive_saved_firstobs;
