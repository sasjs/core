/**
  @file
  @brief Testing mp_hashdataset.sas macro

  <h4> SAS Macros </h4>
  @li mp_hashdataset.sas
  @li mp_assert.sas

**/

/* test 1 - regular DS */
data work.test;
  set sashelp.vextfl;
  missval=.;
  misscval='';
run;

%mp_assertscope(SNAPSHOT)
%mp_hashdataset(test)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Regular test works,
  outds=work.test_results
)

%mp_hashdataset(test,outds=work.test2)

%mp_assert(
  iftrue=(&syscc=0),
  desc=hash with output runs without errors,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.test2)=1),
  desc=output has 1 row,
  outds=work.test_results
)


data work.test3a;
  set work.test;
  stop;
run;
%mp_hashdataset(test3a,outds=work.test3b)

%mp_assert(
  iftrue=(&syscc=0),
  desc=hash with zero-row input runs without errors,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.test3b)=1),
  desc=test 3 output has 1 row,
  outds=work.test_results
)
