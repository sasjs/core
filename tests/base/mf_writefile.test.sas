/**
  @file
  @brief Testing mf_writefile.sas macro

  <h4> SAS Macros </h4>
  @li mf_writefile.sas
  @li mp_assert.sas

**/

%mf_writefile(&sasjswork/myfile.txt,l1=some content,l2=more content)
data _null_;
  infile "&sasjswork/myfile.txt";
  input;
  if _n_=2 then call symputx('test1',_infile_);
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check code ran without errors,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test1=more content),
  desc=Checking line was created,
  outds=work.test_results
)

%mf_writefile(&sasjswork/myfile.txt,l1=some content,l2=different content)
data _null_;
  infile "&sasjswork/myfile.txt";
  input;
  if _n_=2 then call symputx('test2',_infile_);
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check code ran without errors for test2,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test2=different content),
  desc=Checking second line was overwritten,
  outds=work.test_results
)

%global test3 test4;
%mf_writefile(&sasjswork/myfile.txt
  ,mode=a
  ,l1=%str(aah, content)
  ,l2=append content
)
data _null_;
  infile "&sasjswork/myfile.txt";
  input;
  if _n_=2 then call symputx('test3',_infile_);
  if _n_=4 then call symputx('test4',_infile_);
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check code ran without errors for test2,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test3=different content),
  desc=Checking second line was not overwritten,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&test4=append content),
  desc=Checking fourth line was appended,
  outds=work.test_results
)