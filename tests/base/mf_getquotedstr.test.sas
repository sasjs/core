/**
  @file
  @brief Testing mf_getquotedstr macro

  <h4> SAS Macros </h4>
  @li mf_getquotedstr.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

  @details The returned strings contain commas, so they are compared in a data
  step rather than through %EVAL.

**/

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_getquotedstr(blah blah blah);
%mp_assertscope(COMPARE,
  desc=Checking that mf_getquotedstr does not leak scope,
  outds=work.test_results
)

%let q_default=%mf_getquotedstr(blah blah blah);
%let q_double=%mf_getquotedstr(these words are double quoted,quote=D);
%let q_none=%mf_getquotedstr(these words are double quoted,quote=N);
%let q_empty=%mf_getquotedstr();
%let q_dlm=%mf_getquotedstr(a b c,dlm=%str(|));

data work.quoted_check;
  length case $10 actual expect $200;
  case='default';
  actual="%superq(q_default)";
  expect="'blah','blah','blah'";
  output;
  case='double';
  actual="%superq(q_double)";
  expect='"these","words","are","double","quoted"';
  output;
  case='none';
  actual="%superq(q_none)";
  expect="these,words,are,double,quoted";
  output;
  case='empty';
  actual="%superq(q_empty)";
  expect="''";
  output;
  case='dlm';
  actual="%superq(q_dlm)";
  expect="'a'|'b'|'c'";
  output;
run;

proc sql noprint;
  select count(*) into: n_checked from work.quoted_check;
  select count(*) into: n_bad from work.quoted_check where actual ne expect;
quit;

%mp_assert(
  iftrue=(&n_checked=5),
  desc=Checking that all five quoted forms were compared,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_bad=0),
  desc=Checking each quoted form against the string it should return,
  outds=work.test_results
)
