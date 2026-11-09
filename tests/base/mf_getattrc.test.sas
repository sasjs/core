/**
  @file
  @brief Testing mf_getattrc macro

  <h4> SAS Macros </h4>
  @li mf_getattrc.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.attrc_test(label='numericlabel');
  length numvar 8;
  numvar=1;
  output;
run;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getattrc(work.attrc_test,MTYPE);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getattrc does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrc(work.attrc_test,MTYPE)=DATA),
  desc=Checking MTYPE returns DATA for a dataset,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrc(work.attrc_test,LABEL)=numericlabel),
  desc=Checking LABEL returns the label of the dataset,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrc(work.attrc_test,LIB)=WORK),
  desc=Checking LIB returns the library of the dataset,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getattrc(work.no_such_dataset,MTYPE)=-1),
  desc=Checking a dataset that cannot be opened returns -1,
  outds=work.test_results
)
%let syscc=0;
