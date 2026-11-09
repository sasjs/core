/**
  @file
  @brief Testing mp_updatevarlength macro

  <h4> SAS Macros </h4>
  @li mp_updatevarlength.sas
  @li mf_getvarlen.sas
  @li mp_assert.sas

**/

data work.len_update;
  length a $1 b $2;
  a='1';
  b='12';
run;

%mp_updatevarlength(work.len_update,a,3)

%mp_assert(
  iftrue=(%mf_getvarlen(work.len_update,a)=3),
  desc=Checking that the variable is widened to the requested length,
  outds=work.test_results
)

proc sql noprint;
  select a into: val from work.len_update;
quit;

%mp_assert(
  iftrue=(%sysfunc(strip(&val))=1),
  desc=Checking that the stored value survives the length change,
  outds=work.test_results
)

/* a request for the length it already has must return quietly */
%mp_updatevarlength(work.len_update,a,3)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that an unchanged length is a no-op,
  outds=work.test_results
)
