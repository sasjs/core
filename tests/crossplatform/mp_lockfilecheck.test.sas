/**
  @file
  @brief Testing mp_lockfilecheck macro

  <h4> SAS Macros </h4>
  @li mp_lockfilecheck.sas
  @li mp_assert.sas

**/


/* check for regular lock */
data work.test; a=1;run;
%mp_lockfilecheck(work.test)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking regular table can be locked,
  outds=work.test_results
)


/* check for unsuccessful lock */
%global success abortme;
%let success=0;
%macro mp_abort(iftrue=,mac=,msg=);
  %if &abortme=1 %then %let success=1;
%mend mp_abort;

%mp_lockfilecheck(sashelp.class)

%mp_assert(
  iftrue=(&success=1),
  desc=Checking sashelp table cannot be locked,
  outds=work.test_results
)
