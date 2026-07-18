/**
  @file
  @brief Testing mp_rowhash.sas macro
  @details The mp_rowhash macro generates DATA step statements that compute a
    deterministic row-level MD5 hash.  These tests exercise the versioned seed,
    character and numeric hashing rules, variable ordering, sensitivity to
    whitespace, and reproducibility.

  <h4> SAS Macros </h4>
  @li mp_rowhash.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)

/* test 1 - versioned seed only (no input variables) */
data _null_;
  length actual expected $32;
  actual='';
  %mp_rowhash(md5_col=actual)
  expected=put(md5('DC HASH v2'),$hex32.);
  call symputx('t1_actual',actual);
  call symputx('t1_expected',expected);
run;
%mp_assertscope(COMPARE,ignorelist=T1_ACTUAL T1_EXPECTED)
%mp_assert(
  iftrue=("&t1_actual"="&t1_expected"),
  desc=Versioned seed is returned when no variables are supplied,
  outds=work.test_results
)

/* test 2 - single character variable reference */
data _null_;
  length c1 $1 actual expected $32;
  length state digest $16 pair $32;
  c1='A';
  actual='';
  %mp_rowhash(md5_col=actual, cvars=c1)
  state=md5('DC HASH v2');
  digest=md5(trimn(c1));
  pair=state||digest;
  expected=put(md5(pair),$hex32.);
  call symputx('t2_actual',actual);
  call symputx('t2_expected',expected);
run;
%mp_assert(
  iftrue=("&t2_actual"="&t2_expected"),
  desc=Single character variable hash matches reference construction,
  outds=work.test_results
)

/* test 3 - single numeric variable reference */
data _null_;
  length actual expected $32;
  length state digest $16 numtext $64 pair $32;
  n1=42;
  actual='';
  %mp_rowhash(md5_col=actual, nvars=n1)
  state=md5('DC HASH v2');
  /* multiply-by-one matches the internal normalisation */
  normal=n1*1;
  numtext=put(normal,binary64.);
  digest=md5(trim(numtext));
  pair=state||digest;
  expected=put(md5(pair),$hex32.);
  call symputx('t3_actual',actual);
  call symputx('t3_expected',expected);
run;
%mp_assert(
  iftrue=("&t3_actual"="&t3_expected"),
  desc=Single numeric variable hash matches reference construction,
  outds=work.test_results
)

/* test 4 - order of cvars affects the resulting hash */
data _null_;
  length c1 c2 $1 h1 h2 $32;
  c1='A';
  c2='B';
  h1='';
  %mp_rowhash(md5_col=h1, cvars=c1 c2)
  h2='';
  %mp_rowhash(md5_col=h2, cvars=c2 c1)
  call symputx('t4_h1',h1);
  call symputx('t4_h2',h2);
run;
%mp_assert(
  iftrue=("&t4_h1" ne "&t4_h2"),
  desc=Order of cvars changes the resulting hash,
  outds=work.test_results
)

/* test 5 - order of nvars affects the resulting hash */
data _null_;
  length h1 h2 $32;
  n1=1;
  n2=2;
  h1='';
  %mp_rowhash(md5_col=h1, nvars=n1 n2)
  h2='';
  %mp_rowhash(md5_col=h2, nvars=n2 n1)
  call symputx('t5_h1',h1);
  call symputx('t5_h2',h2);
run;
%mp_assert(
  iftrue=("&t5_h1" ne "&t5_h2"),
  desc=Order of nvars changes the resulting hash,
  outds=work.test_results
)

/* test 6 - identical rows produce identical hashes */
data work.test6;
  length c $5 n 8;
  c='ABC';
  n=42;
  output;
  output;
run;

data work.test6_hashed;
  set work.test6;
  length hash $32;
  %mp_rowhash(md5_col=hash, cvars=c, nvars=n)
run;

proc sql noprint;
  select count(distinct hash) into: t6_distinct trimmed
    from work.test6_hashed;
quit;

%mp_assert(
  iftrue=(&t6_distinct=1),
  desc=Identical rows produce identical hashes,
  outds=work.test_results
)

/* test 7 - different rows produce different hashes */
data work.test7;
  length c $5 n 8;
  c='ABC';
  n=42;
  output;
  c='ABD';
  n=42;
  output;
run;

data work.test7_hashed;
  set work.test7;
  length hash $32;
  %mp_rowhash(md5_col=hash, cvars=c, nvars=n)
run;

proc sql noprint;
  select count(distinct hash) into: t7_distinct trimmed
    from work.test7_hashed;
quit;

%mp_assert(
  iftrue=(&t7_distinct=2),
  desc=Different rows produce different hashes,
  outds=work.test_results
)

/* test 8 - leading blanks in character variables are retained */
data work.test8;
  length c $5;
  c=' f';
  output;
  c='f';
  output;
run;

data work.test8_hashed;
  set work.test8;
  length hash $32;
  %mp_rowhash(md5_col=hash, cvars=c)
run;

proc sql noprint;
  select count(distinct hash) into: t8_distinct trimmed
    from work.test8_hashed;
quit;

%mp_assert(
  iftrue=(&t8_distinct=2),
  desc=Leading blanks are retained in character hashes,
  outds=work.test_results
)



