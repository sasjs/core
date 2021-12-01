/**
  @file
  @brief Testing ms_webout macro

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li ms_webout.sas
  @li mp_assert.sas

**/


%let fref=%mf_getuniquefileref();
%global _metaperson;
data some datasets;
  x=1;
run;
%ms_webout(OPEN,fref=&fref)
%ms_webout(ARR,some,fref=&fref)
%ms_webout(OBJ,datasets,fref=&fref)
%ms_webout(CLOSE,fref=&fref)

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