/**
  @file
  @brief Testing mp_md5.sas macro

  <h4> SAS Macros </h4>
  @li mp_md5.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/
%global hash1 hash2 hash3;

%mp_assertscope(SNAPSHOT)
data work.test1 /nonote2err;
  c1='';
  c2=repeat('x',32767);
  c3='  f';
  n1=.a;
  n2=.;
  n3=1.0000000001;
  hash=%mp_md5(cvars=c1 c2 c3,nvars=n1 n2 n3);
  call symputx('hash1',hash);
  n1=.b;
  hash=%mp_md5(cvars=c1 c2 c3,nvars=n1 n2 n3);
  call symputx('hash2',hash);
  c3='f';
  hash=%mp_md5(cvars=c1 c2 c3,nvars=n1 n2 n3);
  call symputx('hash3',hash);
run;
%mp_assertscope(COMPARE,ignorelist=HASH1 HASH2 HASH3)

%mp_assert(
  iftrue=("&hash1" ne "&hash2"),
  desc=Checking first hash diff,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&hash2" ne "&hash3"),
  desc=Checking first hash diff,
  outds=work.test_results
)
