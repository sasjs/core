/**
  @file
  @brief Testing mp_assertscope macro

  <h4> SAS Macros </h4>
  @li mf_getvalue.sas
  @li mp_assert.sas
  @li mp_assertscope.sas


**/

%macro dostuff(action);
  %if &action=ADD %then %do;
    %global NEWVAR1 NEWVAR2;
  %end;
  %else %if &action=DEL %then %do;
    %symdel NEWVAR1 NEWVAR2;
  %end;
  %else %if &action=MOD %then %do;
    %let NEWVAR1=Let us pray..;
  %end;
  %else %if &action=NOTHING %then %do;
    %local a b c d e;
  %end;
%mend dostuff;


/* check for adding variables */
%mp_assertscope(SNAPSHOT)
%dostuff(ADD)
%mp_assertscope(COMPARE,outds=work.testing_the_tester1)
%mp_assert(
  iftrue=(
    "%mf_getvalue(work.testing_the_tester1,test_comments)"
      ="Mod:() Add:(NEWVAR1 NEWVAR2) Del:()"
  ),
  desc=Checking result when vars added,
  outds=work.test_results
)


/* check for modifying variables */
%mp_assertscope(SNAPSHOT)
%dostuff(MOD)
%mp_assertscope(COMPARE,outds=work.testing_the_tester2)
%mp_assert(
  iftrue=(
    "%mf_getvalue(work.testing_the_tester2,test_comments)"
      ="Mod:(NEWVAR1) Add:() Del:()"
  ),
  desc=Checking result when vars modified,
  outds=work.test_results
)

/* check for deleting variables */
%mp_assertscope(SNAPSHOT)
%dostuff(DEL)
%mp_assertscope(COMPARE,outds=work.testing_the_tester3)
%mp_assert(
  iftrue=(
    "%mf_getvalue(work.testing_the_tester3,test_comments)"
      ="Mod:() Add:() Del:(NEWVAR1 NEWVAR2)"
  ),
  desc=Checking result when vars deleted,
  outds=work.test_results
)

/* check for doing nothing */
%mp_assertscope(SNAPSHOT)
%dostuff(NOTHING)
%mp_assertscope(COMPARE,outds=work.testing_the_tester4)
%mp_assert(
  iftrue=(
    "%mf_getvalue(work.testing_the_tester4,test_comments)"
      ="GLOBAL Variables Unmodified"
  ),
  desc=Checking results when nothing created,
  outds=work.test_results
)