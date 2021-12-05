/**
  @file
  @brief Testing mf_existfileref macro

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mp_assert.sas

**/

data work.testme;
x=1;
run;

%mp_assert(
  iftrue=(%mf_existds(work.testme)=1),
  desc=Checking existing dataset exists,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existds(work.try2testme)=0),
  desc=Checking non existing dataset does not exist,
  outds=work.test_results
)