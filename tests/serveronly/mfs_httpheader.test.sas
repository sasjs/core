/**
  @file
  @brief Testing mfs_httpheader.sas macro

  <h4> SAS Macros </h4>
  @li mfs_httpheader.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%let orig_sasjs_stpsrv_header_loc=&sasjs_stpsrv_header_loc;
%let sasjs_stpsrv_header_loc=%sysfunc(pathname(work))/header.txt;

%mp_assertscope(SNAPSHOT)
%mfs_httpheader(Content-Type,application/csv)
%mp_assertscope(COMPARE,ignorelist=sasjs_stpsrv_header_loc)

data _null_;
  infile "&sasjs_stpsrv_header_loc";
  input;
  if _n_=1 then call symputx('test1',_infile_);
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check code ran without errors,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test1"="Content-Type: application/csv"),
  desc=Checking line was created,
  outds=work.test_results
)

%mfs_httpheader(Content-Type,application/text)
%let test2=0;
data _null_;
  infile "&sasjs_stpsrv_header_loc";
  input;
  if _n_=2 then call symputx('test2',_infile_);
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Check code ran without errors for test2,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test2"="Content-Type: application/text"),
  desc=Checking line was created,
  outds=work.test_results
)


/* reset header so the test will pass */
%let sasjs_stpsrv_header_loc=&orig_sasjs_stpsrv_header_loc;