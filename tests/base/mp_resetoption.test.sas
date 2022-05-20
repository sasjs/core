/**
  @file
  @brief Testing mp_resetoption macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_resetoption.sas

**/


%let orig=%sysfunc(getoption(obs));

options obs=30;

%mp_assertscope(SNAPSHOT)
%mp_resetoption(OBS)
%mp_assertscope(COMPARE)

%let new=%sysfunc(ifc(
  "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5",
  %sysfunc(getoption(obs)), /* test it worked */
  &orig /* cannot test as option unavailable */
));

%mp_assert(
  iftrue=(&new=&orig),
  desc=Checking option was reset (if reset option available),
  outds=work.test_results
)
