/**
  @file
  @brief Testing mm_webout macro

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mv_webout.sas
  @li mp_assert.sas

**/


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