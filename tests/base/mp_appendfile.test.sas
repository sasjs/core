/**
  @file
  @brief Testing mp_appendfile.sas macro

  <h4> SAS Macros </h4>
  @li mp_appendfile.sas
  @li mp_assert.sas

**/


filename tmp1 temp;
filename tmp2 temp;
filename tmp3 temp;
data _null_; file tmp1; put 'base file';
data _null_; file tmp2; put 'append1';
data _null_; file tmp3; put 'append2';
run;
%mp_appendfile(baseref=tmp1, appendrefs=tmp2 tmp3)
data _null_;
  infile tmp1;
  input;
  put _infile_;
  call symputx(cats('check',_n_),_infile_);
run;
%global check1 check2 check3;
%mp_assert(
  iftrue=("&check1"="base file"),
  desc=Line 1 of file tmp1 is correct,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&check2"="append1"),
  desc=Line 2 of file tmp1 is correct,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&check3"="append2"),
  desc=Line 3 of file tmp1 is correct,
  outds=work.test_results
)