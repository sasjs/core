/**
  @file
  @brief Testing mp_testwritespeedlibrary macro

  <h4> SAS Macros </h4>
  @li mp_testwritespeedlibrary.sas
  @li mf_existds.sas
  @li mp_assert.sas

**/

/* 0.002 GB keeps the test to a couple of seconds */
%mp_testwritespeedlibrary(lib=WORK,size=0.002,outds=work.write_speed)

proc sql noprint;
  select count(*) into: n_rows from work.write_speed;
  select count(*) into: n_ok from work.write_speed
    where lib='WORK' and duration_seconds ne . and duration_seconds >= 0;
quit;

%mp_assert(
  iftrue=(%mf_existds(work.write_speed)=1 and &n_rows=1),
  desc=Checking that one result row is written,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_ok=1),
  desc=Checking that the library name and a non missing duration are reported,
  outds=work.test_results
)
