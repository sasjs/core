/**
  @file
  @brief Testing mp_gitreleaseinfo.sas macro

  <h4> SAS Macros </h4>
  @li mp_gitreleaseinfo.sas
  @li mp_assert.sas

**/


%mp_gitreleaseinfo(github,sasjs/core,outlib=mylibref,mdebug=1)

%mp_assert(
  iftrue=(&syscc=0),
  desc=mp_gitreleaseinfo runs without errors,
  outds=work.test_results
)

data _null_;
  set mylibref.author;
  putlog (_all_)(=);
  call symputx('author',login);
run;

%mp_assert(
  iftrue=(&author=sasjsbot),
  desc=release info extracted successfully,
  outds=work.test_results
)
