/**
  @file
  @brief Testing mp_ds2csv.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2csv.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.somedata;
  x=1;
  y='  t"w"o';
  z=.z;
  label x='x factor';
run;

/**
  * Test 1 - default CSV
  */
%mp_assertscope(SNAPSHOT)
%mp_ds2csv(work.somedata,outfile="&sasjswork/test1.csv")
%mp_assertscope(COMPARE)

%let test1b=FAIL;
data _null_;
  infile "&sasjswork/test1.csv";
  input;
  list;
  if _n_=1 then call symputx('test1a',_infile_);
  else if _infile_=:'1,"  t""w""o",.Z' then call symputx('test1b','PASS');
run;

%mp_assert(
  iftrue=("&test1a"="x factor, Y, Z"),
  desc=Checking header row Test 1,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test1b"="PASS"),
  desc=Checking data row Test 1,
  outds=work.test_results
)

/**
  * Test 2 - NAME header with fileref and semicolons
  */
filename test2 "&sasjswork/test2.csv";
%mp_ds2csv(work.somedata,outref=test2,dlm=SEMICOLON,headerformat=NAME)

%let test2b=FAIL;
data _null_;
  infile test2;
  input;
  list;
  if _n_=1 then call symputx('test2a',_infile_);
  else if _infile_=:'1;"  t""w""o";.Z' then call symputx('test2b','PASS');
run;

%mp_assert(
  iftrue=("&test2a"="X; Y; Z"),
  desc=Checking header row Test 2,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test2b"="PASS"),
  desc=Checking data row Test 2,
  outds=work.test_results
)

/**
  * Test 3 - SASjs format
  */
filename test3 "&sasjswork/test3.csv";
%mp_ds2csv(work.somedata,outref=test3,headerformat=SASJS)

%let test3b=FAIL;
data _null_;
  infile test3;
  input;
  list;
  if _n_=1 then call symputx('test3a',_infile_);
  else if _infile_=:'1,"  t""w""o",.Z' then call symputx('test3b','PASS');
run;

%mp_assert(
  iftrue=("&test3a"="X:best. Y:$char7. Z:best."),
  desc=Checking header row Test 3,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test3b"="PASS"),
  desc=Checking data row Test 3,
  outds=work.test_results
)