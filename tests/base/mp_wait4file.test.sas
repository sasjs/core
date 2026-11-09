/**
  @file
  @brief Testing mp_wait4file macro

  <h4> SAS Macros </h4>
  @li mp_wait4file.sas
  @li mp_assert.sas

**/

%let flagfile=%sysfunc(pathname(work))/wait4file.flag;

data _null_;
  file "&flagfile";
  put 'here';
run;

/* already present - must return without waiting */
%mp_wait4file(&flagfile,maxwait=5)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that a file that exists passes straight through,
  outds=work.test_results
)

/* absent - must return when the wait expires rather than looping */
%let t0=%sysfunc(datetime());
%mp_wait4file(%sysfunc(pathname(work))/never.flag,maxwait=2,interval=1)
%let elapsed=%sysfunc(intck(second,&t0,%sysfunc(datetime())));

/* no file at all must return rather than sleep on an empty path */
%let t_none=%sysfunc(datetime());
%mp_wait4file(,maxwait=5)
%let waited_none=%sysfunc(intck(second,&t_none,%sysfunc(datetime())));

%mp_assert(
  iftrue=(&waited_none<5),
  desc=Checking that a call with no file returns instead of waiting,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&elapsed>=1 and &elapsed<20),
  desc=Checking that an absent file returns once maxwait expires,
  outds=work.test_results
)
