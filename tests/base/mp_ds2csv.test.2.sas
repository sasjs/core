/**
  @file
  @brief Testing mp_ds2csv.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2csv.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.shortnum;
  length a 3 b 4 c 8;
  a=1;b=2;c=3;
  output;
  stop;
run;

/**
  * Test 1 - default CSV
  */

%mp_ds2csv(work.shortnum,outfile="&sasjswork/test1.csv",headerformat=SASJS)

%let test1b=FAIL;
data _null_;
  infile "&sasjswork/test1.csv";
  input;
  list;
  if _n_=1 then call symputx('test1a',_infile_);
  else if _infile_=:'1,2,3' then call symputx('test1b','PASS');
run;

%mp_assert(
  iftrue=("&test1a"="A:best3. B:best4. C:best."),
  desc=Checking header row Test 1,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test1b"="PASS"),
  desc=Checking data row Test 1,
  outds=work.test_results
)
