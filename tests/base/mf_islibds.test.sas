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
  @li mp_assertscope.sas

**/

data _null_;
  call symput('lf_libds','work.table'||byte(10));
run;
%mp_assertscope(SNAPSHOT)
%put mf_islibds LF result: %mf_islibds(%superq(lf_libds));
%mp_assertscope(COMPARE,
  desc=mf_islibds does not leak macro variables,
  outds=work.test_results
)
/* An unquoted trailing LF is stripped during macro argument handling, so
  the value that reaches validation is work.table and the call is accepted. */
%mp_assert(
  iftrue=(%mf_islibds(&lf_libds)=1),
  desc=Unquoted trailing LF is stripped from the macro argument,
  outds=work.test_results
)
/* Macro quoting preserves the LF as a masked byte, which no longer matches
  the libds expression, so the call is rejected. */
%mp_assert(
  iftrue=(%mf_islibds(%superq(lf_libds))=0),
  desc=Reject a macro-quoted libds ending in LF,
  outds=work.test_results
)

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
