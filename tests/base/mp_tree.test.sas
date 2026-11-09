/**
  @file
  @brief Testing mp_tree macro

  <h4> SAS Macros </h4>
  @li mp_tree.sas
  @li mf_mkdir.sas
  @li mp_assert.sas

**/

%let root=%sysfunc(pathname(work))/tree_test;
%mf_mkdir(&root/sub)

data _null_;
  file "&root/one.txt";
  put 'first';
run;

data _null_;
  file "&root/sub/two.txt";
  put 'second';
run;

%mp_tree(dir=&root,outds=work.tree_out)

proc sql noprint;
  select count(*) into: n_files from work.tree_out
    where index(fullpath,'one.txt')>0;
  select count(*) into: n_nested from work.tree_out
    where index(fullpath,'two.txt')>0;
quit;

%mp_assert(
  iftrue=(&n_files=1),
  desc=Checking that a file in the root of the tree is found,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_nested=1),
  desc=Checking that a file in a subfolder is found,
  outds=work.test_results
)
