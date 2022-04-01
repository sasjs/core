/**
  @file
  @brief Testing mv_webout macro

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mv_webout.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas

**/


/* testing FETCHing (WEB approach) */

data _null_;
  call symputx('sasjs1data','area:$char4.'!!'0d0a'x!!'Adak');
  call symputx('sasjs_tables','areas');
run;
%put &=sasjs1data;

%mv_webout(FETCH)

%mp_assertdsobs(work.areas,
  desc=Test input table has 1 row,
  test=EQUALS 1,
  outds=work.test_results
)


%let fref=%mf_getuniquefileref();
%global _metaperson;
data some datasets;
  x=1;
run;
%mv_webout(OPEN,fref=&fref,stream=N)
%mv_webout(ARR,some,fref=&fref,stream=N)
%mv_webout(OBJ,datasets,fref=&fref,stream=N)
%mv_webout(CLOSE,fref=&fref,stream=N)

data _null_;
  infile &fref;
  input;
  putlog _infile_;
run;

libname test JSON (&fref);
data root;
  set test.root;
  call symputx('checkval',sysvlong);
run;
data alldata;
  set test.alldata;
run;

%mp_assert(
  iftrue=(%str(&checkval)=%str(&sysvlong)),
  desc=Check if the sysvlong value was created
)
