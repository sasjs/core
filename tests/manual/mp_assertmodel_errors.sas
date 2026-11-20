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

/* A trailing control byte in a distinct destination must be rejected. */
data _null_;
  call symput('badout',cats('work.control_result','0A'x));
run;
%mp_assertmodel(work.input,base=work.input,outds=%superq(badout))
%let badoutcc=&syscc;
%let syscc=0;
%mp_assert(iftrue=(&badoutcc>4),desc=Control character destination rejected)
%mp_assert(iftrue=(%sysfunc(exist(work.control_result))=0),
  desc=Control character destination did not create output)

data work.badout / view=work.badout;
  set work.input;
run;
options nosyntaxcheck obs=3 firstobs=2;
%mp_assertmodel(work.input,base=work.input,outds=work.badout)
%let afterobs=%sysfunc(getoption(obs,keyword));
%let afterfirstobs=%sysfunc(getoption(firstobs,keyword));
options obs=max firstobs=1;
%let syscc=0;
%mp_assert(iftrue=("&afterobs"="OBS=3"),
  desc=Failed append restores observation limit)
%mp_assert(iftrue=("&afterfirstobs"="FIRSTOBS=2"),
  desc=Failed append restores first observation)

options syntaxcheck obs=3 firstobs=2;
%mp_assertmodel(work.input,base=work.input,outds=work.badout)
%let syntaxobs=%sysfunc(getoption(obs,keyword));
%let syntaxfirstobs=%sysfunc(getoption(firstobs,keyword));
%let syntaxreplace=%sysfunc(getoption(replace,keyword));
%put NOTE: PROBE_SYNTAX_OBS=&syntaxobs REPLACE=&syntaxreplace;
options nosyntaxcheck obs=max firstobs=1 replace;
%let syscc=0;
%mp_assert(iftrue=("&syntaxobs"="OBS=3"),
  desc=Failed append restores observation limit under syntax check)
%mp_assert(iftrue=("&syntaxreplace"="NOREPLACE"),
  desc=Syntax check NOREPLACE remains set)
%mp_assert(iftrue=("&syntaxfirstobs"="FIRSTOBS=2"),
  desc=Syntax check restores first observation)

/* Print the actual result rows for a standalone sasjs run log. */
data _null_;
  set work.test_results;
  putlog 'PROBE_RESULT: ' test_result +1 test_description;
run;
