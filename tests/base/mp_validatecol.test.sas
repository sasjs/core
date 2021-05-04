/**
  @file
  @brief Testing mp_validatecol.sas macro

  <h4> SAS Macros </h4>
  @li mp_assertdsobs.sas
  @li mp_validatecol.sas

**/


/**
  * Test 1 - LIBDS
  */
data test1;
  infile datalines4 dsd;
  input;
  libds=_infile_;
  %mp_validatecol(libds,LIBDS,is_libds)
  if libds=1;
datalines4;
some.libname
!lib.blah
%abort
definite.ok
not.ok!
nineletrs._
;;;;
run;
%mp_assertdsobs(work.test1,
  desc=Testing LIBDS,
  test=EQUALS 2,
  outds=work.test_results
)

/**
  * Test 2 - ISNUM
  */
data test2;
  infile datalines4 dsd;
  input;
  infile=_infile_;
  %mp_validatecol(infile,ISNUM,is_numeric)
  if is_numeric=1;
datalines4;
1
0001
1e6
-44
above are good
the rest are bad
%abort
1&somethingverybad.
&
+-1
;;;;
run;
%mp_assertdsobs(work.test2,
  desc=Test2 - ISNUM,
  test=EQUALS 4,
  outds=work.test_results
)