/**
  @file
  @brief Testing mf_dttmfmts macro

  <h4> SAS Macros </h4>
  @li mf_dttmfmts.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* the macro call must not sit between the snapshots behind a %let - that
  would register the test's own macro variable as a leak */
%mp_assertscope(SNAPSHOT)
%put %mf_dttmfmts(DATE);
%mp_assertscope(COMPARE,
  desc=mf_dttmfmts does not leak scope,
  outds=work.test_results
)

%let datelist=%mf_dttmfmts(DATE);
%let dtlist=%mf_dttmfmts(DATETIME);
%let timelist=%mf_dttmfmts(TIME);
%let lowerlist=%mf_dttmfmts(date);

/* the lists hold commas, so they are inspected in a data step rather than
  passed to a macro function */
data _null_;
  length dl dt tl $4000;
  dl=symget('datelist');
  dt=symget('dtlist');
  tl=symget('timelist');
  call symputx('date_has_mmddyy',(index(dl,"'MMDDYY'")>0));
  call symputx('date_has_hhmm',(index(dl,"'HHMM'")>0));
  call symputx('dt_has_dateampm',(index(dt,"'DATEAMPM'")>0));
  call symputx('dt_has_mmddyy',(index(dt,"'MMDDYY'")>0));
  call symputx('time_has_hhmm',(index(tl,"'HHMM'")>0));
  call symputx('time_has_mmddyy',(index(tl,"'MMDDYY'")>0));
  call symputx('quoted',(index(dl,"'")>0));
  call symputx('ci_ok',(dl=symget('lowerlist')));
run;

%mp_assert(
  iftrue=(&date_has_mmddyy=1),
  desc=DATE list holds a date format,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&date_has_hhmm=0),
  desc=DATE list does not hold a time format,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&dt_has_dateampm=1),
  desc=DATETIME list holds DATEAMPM,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&dt_has_mmddyy=0),
  desc=DATETIME list does not hold a date format,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&time_has_hhmm=1),
  desc=TIME list holds a time format,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&time_has_mmddyy=0),
  desc=TIME list does not hold a date format,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&quoted=1),
  desc=the list is quoted so it can be used in an in clause,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&ci_ok=1),
  desc=type is case insensitive,
  outds=work.test_results
)

/* the scope check above writes straight to the results, so this is what
  proves it passed */
data _null_;
  retain fails 0;
  set work.test_results end=last;
  if test_result='FAIL' then fails=fails+1;
  if last then call symputx('nrfails',fails);
run;
%mp_assert(
  iftrue=(&nrfails=0),
  desc=no assertion in this test failed,
  outds=work.test_results
)
