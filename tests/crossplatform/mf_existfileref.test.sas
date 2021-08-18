/**
  @file
  @brief Testing mf_existfileref macro

  <h4> SAS Macros </h4>
  @li mf_existfileref.sas
  @li mp_assert.sas

**/

filename ref1 temp;
filename ref2 temp;

data _null_;
  file ref1;
  put 'exists';
run;

%mp_assert(
  iftrue=(%mf_existfileref(ref1)=1),
  desc=Checking fileref WITH target file exists,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existfileref(ref2)=1),
  desc=Checking fileref WITHOUT target file exists,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existfileref(ref3)=0),
  desc=Checking non-existant fref does not exist,
  outds=work.test_results
)
