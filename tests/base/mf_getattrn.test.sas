/**
  @file
  @brief Testing mf_getattrn macro

  <h4> SAS Macros </h4>
  @li mf_getattrn.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.attrn_test;
  length charvar $10 numvar 8;
  do numvar=1 to 4;
    charvar=cats('row',numvar);
    output;
  end;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getattrn(work.attrn_test,NLOBS);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getattrn does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrn(work.attrn_test,NLOBS)=4),
  desc=Checking NLOBS returns the observation count,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrn(work.attrn_test,NVARS)=2),
  desc=Checking NVARS returns the variable count,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrn(work.no_such_dataset,NLOBS)=-1),
  desc=Checking a dataset that cannot be opened returns -1,
  outds=work.test_results
)
