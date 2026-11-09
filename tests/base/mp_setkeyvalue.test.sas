/**
  @file
  @brief Testing mp_setkeyvalue macro

  <h4> SAS Macros </h4>
  @li mp_setkeyvalue.sas
  @li mf_getkeyvalue.sas
  @li mp_assert.sas

**/

%mp_setkeyvalue(numkey,42,type=N)
%mp_setkeyvalue(charkey,a value)
%mp_setkeyvalue(charkey,another value)

proc sql noprint;
  select count(*) into: n_rows from work.mp_setkeyvalue;
  select count(*) into: n_num from work.mp_setkeyvalue where key='numkey';
quit;

%mp_assert(
  iftrue=(&n_rows=2),
  desc=Checking that setting the same key twice leaves a single row,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_getkeyvalue(numkey)=42),
  desc=Checking that a numeric value round trips,
  outds=work.test_results
)

/* the value carries a space, so it is compared in a data step rather than
  through %EVAL */
%let charval=%sysfunc(strip(%mf_getkeyvalue(charkey)));

data work.kv_check;
  length charval $40;
  charval="%superq(charval)";
  ok=0;
  if charval='another value' then ok=1;
run;

proc sql noprint;
  select ok into: kv_ok from work.kv_check;
quit;

%mp_assert(
  iftrue=(&kv_ok=1),
  desc=Checking that the second value for a key replaces the first,
  outds=work.test_results
)
