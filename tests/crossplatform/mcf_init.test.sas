/**
  @file
  @brief Testing mcf_init.sas macro

  <h4> SAS Macros </h4>
  @li mcf_init.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(%mcf_init(test)=0),
  desc=Check if new func returns 0
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs on basic invocation
)
%mp_assert(
  iftrue=(%mcf_init(test)=1),
  desc=Check if second invocation returns 1
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs on second invocation
)
%mp_assert(
  iftrue=(%mcf_init(test2)=0),
  desc=Check if new invocation returns 0
)
%mp_assert(
  iftrue=(%mcf_init(test2)=1),
  desc=Check if second new invocation returns 1
)
%mp_assert(
  iftrue=(%mcf_init(test)=1),
  desc=Check original returns 1
)
%mp_assert(
  iftrue=(%mcf_init(t)=1),
  desc=Check subset returns 1
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs at end
)