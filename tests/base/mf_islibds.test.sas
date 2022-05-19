/**
  @file
  @brief Testing mf_islibds macro

      %put %mf_islibds(work.something)=1;
      %put %mf_islibds(nolib)=0;
      %put %mf_islibds(badlibref.ds)=0;
      %put %mf_islibds(w.t.f)=0;

  <h4> SAS Macros </h4>
  @li mf_islibds.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    %mf_islibds(work.something)=1
  ),
  desc=%str(Checking mf_islibds(work.something)=1),
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(nolib)=0
  ),
  desc=%str(Checking mf_islibds(nolib)=0),
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(badlibref.ds)=0
  ),
  desc=%str(Checking mf_islibds(badlibref.ds)=0),
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(w.t.f)=0
  ),
  desc=%str(Checking mf_islibds(w.t.f)=0),
  outds=work.test_results
)
