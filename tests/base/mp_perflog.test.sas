/**
  @file
  @brief Testing mp_perflog macro

  <h4> SAS Macros </h4>
  @li mp_perflog.sas
  @li mf_existds.sas
  @li mp_assert.sas

**/

%mp_perflog(started)
%mp_perflog(finished)

proc sql noprint;
  select count(*) into: n_rows from work.mp_perflog;
  select count(*) into: n_started from work.mp_perflog where label='started';
quit;

%mp_assert(
  iftrue=(&n_rows=2),
  desc=Checking that each call appends a row to the log dataset,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_started=1),
  desc=Checking that the label is stored on the row it was logged with,
  outds=work.test_results
)

%mp_perflog(startanew,libds=work.perflog_two)
%mp_assert(
  iftrue=(%mf_existds(work.perflog_two)=1),
  desc=Checking that a named log dataset is created on first use,
  outds=work.test_results
)
