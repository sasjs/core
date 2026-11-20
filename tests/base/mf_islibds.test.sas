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

%mp_assert(
  iftrue=(
    %mf_islibds(abcdefgh.ds)=1
  ),
  desc=Accept 8-character libref,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(1lib.ds)=0
  ),
  desc=Reject libref starting with a digit,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(work.1data)=0
  ),
  desc=Reject dataset name starting with a digit,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(work.st_mods)=1
  ),
  desc=Accept underscore in dataset name,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(lib_ref.data)=1
  ),
  desc=Accept underscore in libref,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(WORK.DATA)=1
  ),
  desc=Accept uppercase libref and dataset name,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(w.abcdefghijklmnopqrstuvwxyz123456)=1
  ),
  desc=Accept 32-character dataset name,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    %mf_islibds(w.abcdefghijklmnopqrstuvwxyz1234567)=0
  ),
  desc=Reject 33-character dataset name,
  outds=work.test_results
)
