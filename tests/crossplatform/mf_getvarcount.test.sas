/**
  @file
  @brief Testing mf_getvarlist macro

  <h4> SAS Macros </h4>
  @li mf_getvarcount.sas

**/

data work.all work.nums(keep=num1 num2) work.chars(keep=char1 char2);
  length num1 num2 8 char1 char2 char3 $4;
  call missing (of _all_);
  output;
run;

%mp_assert(
  iftrue=(%mf_getvarcount(work.all)=5),
  desc=%str(Checking for mixed vars),
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_getvarcount(work.all,typefilter=C)=3),
  desc=%str(Checking for char in mixed vars),
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_getvarcount(work.all,typefilter=N)=2),
  desc=%str(Checking for num in mixed vars),
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_getvarcount(work.nums,typefilter=c)=0),
  desc=%str(Checking for char in num vars),
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_getvarcount(work.chars,typefilter=N)=0),
  desc=%str(Checking for num in char vars),
  outds=work.test_results
)

