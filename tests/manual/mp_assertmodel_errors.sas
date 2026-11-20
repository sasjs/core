/**
  @file
  @brief Isolated error-path probes for mp_assertmodel
  @details Run separately from the standard suite because expected errors are
  deliberately emitted. The runner must inspect each assertion row and the
  log. Never interpret these expected errors as a clean normal test run.
  Dataset names in this probe deliberately include control characters.
  <h4> SAS Macros </h4>
  @li mp_assertmodel.sas
  @li mp_assert.sas
**/
data work.input;
  id=1;
run;
%let syscc=0;
%mp_assertmodel(work.input,base=work.input,outds=work.input)
%let overlapcc=&syscc;
%let syscc=0;
%mp_assert(iftrue=(&overlapcc>4),desc=Overlap rejection sets failure status)

%mp_assertmodel(work.input(where=(id=1)),base=work.input)
%let invalidcc=&syscc;
%let syscc=0;
%mp_assert(iftrue=(&invalidcc>4),desc=Invalid reference sets failure status)

/* An embedded control byte in a distinct destination must be rejected. */
data _null_;
  call symput('badout','work.control'||'0A'x||'_result');
run;
proc sql noprint;
  select count(*) into :before_count trimmed
  from dictionary.tables where libname='WORK';
quit;
%mp_assertmodel(work.input,base=work.input,outds=%superq(badout))
%let badoutcc=&syscc;
%let syscc=0;
proc sql noprint;
  select count(*) into :after_count trimmed
  from dictionary.tables where libname='WORK';
quit;
%mp_assert(iftrue=(&badoutcc>4),desc=Control character destination rejected)
%mp_assert(iftrue=(&before_count=&after_count),
  desc=Control character destination did not create output)

%let originalsyntax=%sysfunc(getoption(syntaxcheck,keyword));
options nosyntaxcheck;
data work.badout / view=work.badout;
  set work.input;
run;
%mp_assertmodel(work.input,base=work.input,outds=work.badout)
%let appendcc=&syscc;
%let syscc=0;
options &originalsyntax;
%mp_assert(iftrue=(&appendcc>4),desc=Failed append sets failure status)

/* Print the actual result rows for a standalone sasjs run log. */
data _null_;
  set work.test_results;
  putlog 'PROBE_RESULT: ' test_result +1 test_description;
run;
