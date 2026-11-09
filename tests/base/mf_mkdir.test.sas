/**
  @file
  @brief Testing mf_mkdir macro

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%let root=%sysfunc(pathname(work))/mkdir_test;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_mkdir(&root/a/b/c);
%mp_assertscope(COMPARE,
  desc=Checking that mf_mkdir does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(fileexist(&root/a/b/c))=1),
  desc=Checking that intermediate directories are created,
  outds=work.test_results
)

%mf_mkdir(&root/a/b/c/)
%mp_assert(
  iftrue=(&syscc=0 and %sysfunc(fileexist(&root/a/b/c))=1),
  desc=Checking that a trailing slash is accepted and an existing path is quiet,
  outds=work.test_results
)

%mf_mkdir(/)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that a single slash is treated as an existing root,
  outds=work.test_results
)
