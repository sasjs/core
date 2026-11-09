/**
  @file
  @brief Testing mp_recursivejoin macro

  <h4> SAS Macros </h4>
  @li mp_recursivejoin.sas
  @li mp_assert.sas

**/

data work.have;
  p=1;c=2;output;
  p=2;c=3;output;
  p=2;c=4;output;
  p=3;c=5;output;
  p=6;c=7;output;
  p=8;c=9;output;
run;

%mp_recursivejoin(base_ds=work.have,outds=work.want,matchval=1
  ,parentvar=p,childvar=c)

proc sql noprint;
  select count(*) into: n_pairs from work.want
    where (p=1 and c=2) or (p=2 and c=3) or (p=2 and c=4) or (p=3 and c=5);
  select count(*) into: n_deep from work.want where c=5;
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
