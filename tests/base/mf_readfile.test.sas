/**
  @file
  @brief Testing mf_readfile.sas macro

  <h4> SAS Macros </h4>
  @li mf_readfile.sas
  @li mp_assert.sas

**/

%let f=&sasjswork/myfile.txt;

%mf_writefile(&f,l1=some content,l2=more content)
data _null_;
  infile "&f";
  input;
  putlog _infile_;
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check code ran without errors,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&f=some content),
  desc=Checking first line was ingested successfully,
  outds=work.test_results
)
