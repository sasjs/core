/**
  @file
  @brief Test rejected calls and failed appends in mp_assertmodel

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas
**/

%macro test_model_errors();
  %local syntax badout before_count after_count errorcc;
  %let syntax=%sysfunc(getoption(syntaxcheck,keyword));
  options nosyntaxcheck;

  data work.input;
    id=1;
  run;

  /* These calls deliberately produce errors; capture and reset SYSCC. */
  %mp_assertscope(SNAPSHOT)
  %mp_assertmodel(work.input,base=work.input,outds=work.input)
  %let errorcc=&syscc;
  %let syscc=0;
  %mp_assertscope(COMPARE,desc=Overlap rejection does not leak scope)
  %mp_assert(iftrue=(&errorcc>4),desc=Overlap rejection sets failure status)
  proc sql noprint;
    select count(*) into :after_count trimmed from work.input where id=1;
  quit;
  %mp_assert(iftrue=(&after_count=1),desc=Overlap rejection preserves input)

  %mp_assertscope(SNAPSHOT)
  %mp_assertmodel(work.input(where=(id=1)),base=work.input)
  %let errorcc=&syscc;
  %let syscc=0;
  %mp_assertscope(COMPARE,desc=Invalid reference does not leak scope)
  %mp_assert(iftrue=(&errorcc>4),desc=Invalid reference sets failure status)

  /* An embedded control byte must not create an output table. */
  data _null_;
    call symputx('badout','work.control'||'0A'x||'_result','L');
  run;
  %mp_assertscope(SNAPSHOT)
  proc sql noprint;
    select count(*) into :before_count trimmed
    from dictionary.tables where libname='WORK';
  quit;
  %mp_assertmodel(work.input,base=work.input,outds=%superq(badout))
  %let errorcc=&syscc;
  %let syscc=0;
  proc sql noprint;
    select count(*) into :after_count trimmed
    from dictionary.tables where libname='WORK';
  quit;
  %mp_assertscope(COMPARE,desc=Control character rejection does not leak scope)
  %mp_assert(iftrue=(&errorcc>4),desc=Control character destination rejected)
  %mp_assert(iftrue=(&before_count=&after_count),
    desc=Control character destination did not create output)

  data work.badout / view=work.badout;
    set work.input;
  run;
  %mp_assertscope(SNAPSHOT)
  %mp_assertmodel(work.input,base=work.input,outds=work.badout)
  %let errorcc=&syscc;
  %let syscc=0;
  %mp_assertscope(COMPARE,desc=Failed append does not leak scope)
  %mp_assert(iftrue=(&errorcc>4),desc=Failed append sets failure status)

  options &syntax;
%mend test_model_errors;
%test_model_errors()
